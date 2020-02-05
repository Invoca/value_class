# frozen_string_literal: true

# TODO: only allow named timeouts
# TODO: Allow class table sets... (Maybe. Would rather do something different for ringswitch delayed job connection)
# TODO: Worried about release connection. (Does connection pool do this?)
#        Need reference counted connections
#          a => b => a => b
#        Should only release when count goes to zero...

require 'exception_handling'

module ActiveTableSet
  class ConnectionManager

    QUARANTINE_DURATION = 60.seconds

    def initialize(config:, connection_handler:)
      @config             = config
      @connection_handler = connection_handler
      @connection_specs   = {}
      @current_pool_keys  = {}
      @quarantine_until   = {}

      connection_handler.default_spec(current_specification)
    end

    # This object remembers a reset block. When `reset` is called, it executes that block.
    class ProxyForReset
      def initialize(&reset_block)
        @reset_block = reset_block
      end

      def reset
        @reset_block&.call
      end
    end

    # Wrapper to avoid cascading exceptions hiding the original cause.
    # Calls the passed-in block. On the way out, calls the cleanup_block.
    # If an exception is raised by either of those, it is passed through,
    # but if both happen, the former is passed through and the latter
    # is logged with `ensure_safe`.
    def ensure_safe_cleanup(context, block, &cleanup_block)
      result = block.call
    rescue Exception
      ExceptionHandling.ensure_safe(context, database: current_specification.config["database"]) { cleanup_block.call }
      raise
    else
      cleanup_block.call
      result
    end

    # If a block is given, runs the block using the given settings and resets to the old on the way out.
    # If no block is given, changes the settings and returns a handler which does the reset when `reset` is called on it.
    def using(table_set: nil, access: nil, partition_key: nil, timeout: nil, &blk)
      handler = override(table_set: table_set, access: access, partition_key: partition_key, timeout: timeout)
      if block_given?
        ensure_safe_cleanup("using resetting with old settings", blk) do
          handler&.reset
        end
      else
        handler
      end
    end

    def use_test_scenario(test_scenario_name)
      @test_scenario_name = test_scenario_name  # store in case other threads/fibers call settings below

      new_settings = settings.merge(test_scenario: test_scenario_name)

      @connection_handler.test_scenario_connection_spec = connection_attributes(new_settings).pool_key.connection_spec(new_settings.table_set)

      if new_settings != settings
        release_connection
        self._settings = new_settings
        establish_connection
      end
    end

    def lock_access(access, &blk)
      old_lock = _access_lock
      self._access_lock = access
      begin
        using(access: access, &blk)
      ensure
        self._access_lock = old_lock
      end
    end

    def access_policy
      if !_access_policy_disabled && @config.enforce_access_policy
        orig_access_policy = connection_attributes(settings).access_policy
        if settings.access == :leader
          orig_access_policy
        else
          # Disallow all writes on follower or balanced access.
          ActiveTableSet::Configuration::AccessPolicy.new(
            allow_read: orig_access_policy.allow_read,
            allow_write: '',
            disallow_read: orig_access_policy.disallow_read,
            disallow_write: '%'
          )
        end
      end
    end

    def allow_test_access
      old_access_policy_setting = _access_policy_disabled
      self._access_policy_disabled = true
      yield
    ensure
      self._access_policy_disabled = old_access_policy_setting
    end

    def connection_pool_stats
      @connection_handler.connection_pool_stats
    end

    def reap_connections
      @connection_handler.reap_connections
    end

    # If host is set as a lambda, this removes the cached pool key
    # So the lambda will be called again
    def reload_pool_key
      @connection_specs.clear
      @current_pool_keys.clear
    end

    def current_specification
      pool_key_for_settings(settings).connection_spec(settings.table_set)
    end

    def exception_should_retry_connection?(ex)
      ex.message =~ /Can't connect/
    end

    private

    def override(table_set: nil, access: nil, partition_key: nil, timeout: nil)
      effective_table_set = table_set || settings.table_set
      effective_partition_key = partition_key || settings.partition_key

      effective_access = access_override_from_process_settings(effective_table_set, effective_partition_key) || _access_lock || access

      new_settings = settings.merge(
        table_set:     table_set,
        access:        effective_access,
        partition_key: partition_key,
        timeout:       timeout
      )

      if new_settings == settings
        ProxyForReset.new
      else
        new_connection_attributes     = connection_attributes(new_settings)
        current_connection_attributes = connection_attributes(settings)

        if new_connection_attributes == current_connection_attributes
          # Tests use the same connection attributes, so override the access policy just in case.
          override_with_new_access_policy(new_settings)
        else
          override_with_new_connection(new_settings)
        end
      end
    end

    def access_override(table_set, partition_key)
      access_override_from_process_settings(table_set, partition_key) || _access_lock
    end

    # Overrides the settings and makes a new connection with those.
    # Returns an object with a `reset` method to use for resetting the connection.
    def override_with_new_connection(new_settings)
      old_settings    = self._settings
      self._settings  = new_settings
      proxy_for_reset = ProxyForReset.new do
        ensure_safe_cleanup("override_with_new_connection re-establishing connection with old settings: #{old_settings.inspect}",
                            -> { release_connection }) do
          self._settings = old_settings
          establish_connection
        end
      end

      establish_connection
      proxy_for_reset
    rescue
      ExceptionHandling.ensure_safe("override_with_new_connection: resetting", database: current_specification.config["database"]) { proxy_for_reset.reset }
      raise
    end

    def override_with_new_access_policy(new_settings)
      old_settings   = self._settings
      self._settings = new_settings
      ProxyForReset.new { self._settings = old_settings }
    end

    include ValueClass::ThreadLocalAttribute
    thread_local_instance_attr :_settings
    thread_local_instance_attr :_access_lock
    thread_local_instance_attr :_access_policy_disabled

    def settings
      self._settings ||= @config.default.merge(
        access: access_override(@config.default.table_set, @config.default.partition_key) || @config.default.access,
        test_scenario: @test_scenario_name
      )
    end

    def establish_connection
      if failover_available?
        connect_using_preferred_spec
      else
        safely_establish_connection(
          spec: current_specification,
          spec_when_error: current_specification,
          quarantine_failed: false
        )
      end
    end

    def connect_using_preferred_spec
      if connection_quarantined?(current_specification)
        establish_connection_using_spec(failover_specification)
      else
        safely_establish_connection(
          spec: current_specification,
          spec_when_error: failover_specification,
          quarantine_failed: true
        )
      end
    end

    def safely_establish_connection(spec:, spec_when_error:, quarantine_failed:)
      establish_connection_using_spec(spec)
    rescue => ex
      ExceptionHandling.log_error(ex, "Failure establishing database connection using spec: #{spec.inspect} because of #{ex.message}", database: spec&.config["database"])

      if exception_should_retry_connection?(ex)
        reload_pool_key

        if quarantine_failed
          quarantine_connection(spec)
        end

        if spec_when_error
          establish_connection_using_spec(spec_when_error)
        end
      end
    end

    def establish_connection_using_spec(connection_specification)
      if (blk = @config.before_enable(settings))
        blk.call
      end

      @connection_handler.current_spec = connection_specification
      test_connection
    end

    def pool_key_for_settings(settings)
      @current_pool_keys[settings] ||= connection_attributes(settings).pool_key
    end

    def failover_specification
      if failover_available?
        connection_attributes(settings).failover_pool_key.connection_spec(settings.table_set)
      end
    end

    def test_connection
      @connection_handler.retrieve_connection_pool("ActiveRecord::Base").connection
    end


    def failover_available?
      connection_attributes(settings).failover_pool_key
    end

    def quarantine_connection(specification)
      @quarantine_until[specification.config] = Time.now + QUARANTINE_DURATION
    end

    def connection_quarantined?(specification)
      @quarantine_until[specification.config] && @quarantine_until[specification.config] > Time.now
    end

    def release_connection
      @connection_handler.pool_for_spec(current_specification)&.release_connection
    end

    def access_override_from_process_settings(table_set, partition_key)
      scoped_setting_key = [table_set, partition_key].compact.join('-')
      ProcessSettings['active_table_set', scoped_setting_key, 'access_override', required: false]&.to_sym ||
        ProcessSettings['active_table_set', 'default', 'access_override', required: false]&.to_sym
    end

    def connection_attributes(settings)
      @connection_specs[settings] ||= @config.connection_attributes(settings)
    end
  end
end
