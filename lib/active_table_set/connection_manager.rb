# frozen_string_literal: true

# TODO: only allow named timeouts
# TODO: Allow class table sets... (Maybe. Would rather do something different for ringswitch delayed job connection)
# TODO: Worried about release connection. (Does connection pool do this?)
#        Need reference counted connections
#          a => b => a => b
#        Should only release when count goes to zero...

require 'exception_handling'
require 'process_flags'

module ActiveTableSet
  class ConnectionManager

    QUARANTINE_DURATION = 60.seconds

    def initialize(config:, connection_handler:)
      @config             = config
      @connection_handler = connection_handler
      @connection_specs   = {}
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
      ExceptionHandling.ensure_safe(context, &cleanup_block)
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
      unless _access_policy_disabled
        @config.enforce_access_policy && connection_attributes(settings).access_policy
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

    private

    def override(table_set: nil, access: nil, partition_key: nil, timeout: nil)
      new_settings = settings.merge(
        table_set:     table_set,
        access:        process_flag_access || _access_lock || access,
        partition_key: partition_key,
        timeout:       timeout
      )

      if new_settings == settings
        ProxyForReset.new
      else
        new_connection_attributes     = connection_attributes(new_settings)
        current_connection_attributes = connection_attributes(settings)

        if new_connection_attributes == current_connection_attributes
          ProxyForReset.new
        elsif new_connection_attributes.pool_key == current_connection_attributes.pool_key
          override_with_new_access_policy(new_settings)
        else
          override_with_new_connection(new_settings)
        end
      end
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
      ExceptionHandling.ensure_safe("override_with_new_connection: resetting") { proxy_for_reset.reset }
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
      self._settings ||= @config.default.merge(test_scenario: @test_scenario_name)
    end

    def establish_connection
      if failover_available?
        if connection_quarantined?(current_specification)
          establish_connection_using_spec(failover_specification)
        else
          begin
            establish_connection_using_spec(current_specification)
          rescue => ex
            ExceptionHandling.log_error(ex, "Failure checking out alternate database connection")

            quarantine_connection(current_specification)

            establish_connection_using_spec(failover_specification)
          end
        end
      else
        establish_connection_using_spec(current_specification)
      end
    end

    def establish_connection_using_spec(connection_specification)
      if blk = @config.before_enable(settings)
        blk.call
      end
      @connection_handler.current_spec = connection_specification
      test_connection
    end

    def current_specification
      connection_attributes(settings).pool_key.connection_spec(settings.table_set)
    end

    def failover_specification
      if connection_attributes(settings).failover_pool_key
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

    def process_flag_access
      ProcessFlags.is_set?(:disable_alternate_databases) ? :leader : nil
    end

    def connection_attributes(settings)
      @connection_specs[settings] ||= @config.connection_attributes(settings)
    end
  end
end
