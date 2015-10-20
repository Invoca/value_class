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

    QUARANTINE_DURATION_SECONDS = 60

    def initialize(config:, connection_handler:)
      @config             = config
      @connection_handler = connection_handler
      @connection_specs   = {}
      @quarantine_until   = {}

      connection_handler.default_spec(current_specification)
    end

    def using(table_set: nil, access: nil, partition_key: nil, timeout: nil, &blk)
      new_request = request.merge(
        table_set:     table_set,
        access:        process_flag_access || _access_lock || access,
        partition_key: partition_key,
        timeout:       timeout
      )

      if new_request == request
        yield
      else
        new_connection_spec     = connection_spec(new_request)
        current_connection_spec = connection_spec(request)

        if new_connection_spec == current_connection_spec
          yield
        elsif new_connection_spec.pool_key == current_connection_spec.pool_key
          yield_with_new_access_policy(new_request, &blk)
        else
          yield_with_new_connection(new_request, &blk)
        end
      end
    end

    def use_test_scenario(test_scenario_name)
      new_request = request.merge(test_scenario: test_scenario_name)

      if new_request != request
        release_connection
        self._request = new_request
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
        @config.enforce_access_policy && connection_spec(request).access_policy
      end
    end

    def allow_test_access
      old_access_policy_setting = _access_policy_disabled
      self._access_policy_disabled = true
      yield
    ensure
      self._access_policy_disabled = old_access_policy_setting
    end

    private

    include ValueClass::ThreadLocalAttribute
    thread_local_instance_attr :_request
    thread_local_instance_attr :_access_lock
    thread_local_instance_attr :_access_policy_disabled

    def request
      self._request ||= @config.default
    end

    def yield_with_new_access_policy(new_request)
      old_request   = _request
      self._request = new_request

      yield

    ensure
      self._request = old_request
    end

    def yield_with_new_connection(new_request)
      old_request   = _request
      self._request = new_request

      establish_connection

      yield

    ensure
      begin
        release_connection
      ensure
        self._request = old_request
        establish_connection
      end
    end

    def establish_connection
      if failover_available?
        if connection_quarantined?(current_specification)
          @connection_handler.current_spec = failover_specification
          test_connection
        else
          begin
            @connection_handler.current_spec = current_specification
            test_connection
          rescue => ex
            ExceptionHandling.log_error(ex, "Failure checking out alternate database connection")

            quarantine_connection(current_specification)

            @connection_handler.current_spec = failover_specification
            test_connection
          end
        end
      else
        @connection_handler.current_spec = current_specification
        test_connection
      end
    end

    def current_specification
      connection_spec(request).pool_key.connection_spec
    end

    def failover_specification
      if connection_spec(request).failover_pool_key
        connection_spec(request).failover_pool_key.connection_spec
      end
    end

    def test_connection
      @connection_handler.retrieve_connection_pool("ActiveRecord::Base").connection
    end


    def failover_available?
      connection_spec(request).failover_pool_key
    end

    def quarantine_connection(specification)
      @quarantine_until[specification.config] = Time.now + QUARANTINE_DURATION_SECONDS
    end

    def connection_quarantined?(specification)
      @quarantine_until[specification.config] && @quarantine_until[specification.config] > Time.now
    end

    def release_connection
      pool = @connection_handler.pool_for_spec(current_specification)
      pool && pool.release_connection
    end

    def process_flag_access
      ProcessFlags.is_set?(:disable_alternate_databases) ? :leader : nil
    end

    def connection_spec(request)
      @connection_specs[request] ||= @config.connection_spec(request)
    end
  end
end
