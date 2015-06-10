# TODO: quarantine
# TODO: failback
# TODO: only allow named timeouts
# TODO: How to override connection?
#
# TODO: Not sure about calling establish connection because it destroys previous connection
#
#require 'mysql2'


module ActiveTableSet
  class ConnectionManager

    def initialize(config:, connection_handler:)
      @config             = config
      @connection_handler = connection_handler
      @connection_specs   = {}

      connection_handler.default_spec(current_specification)
    end

    def using(table_set: nil, access: nil, partition_key: nil, timeout: nil, &blk)
      new_request = request.merge(
        table_set:     table_set,
        access:        _access_lock || access,
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
      @config.enforce_access_policy && connection_spec(request).access_policy
    end

    private

    include ValueClass::ThreadLocalAttribute
    thread_local_instance_attr :_request
    thread_local_instance_attr :_access_lock
    thread_local_instance_attr :_spec

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
      release_connection
      self._request    = old_request
      establish_connection
    end

    def establish_connection
      @connection_handler.current_spec = current_specification
    end

    def current_specification
      con_spec = connection_spec(request).pool_key
      ActiveRecord::ConnectionAdapters::ConnectionSpecification.new(con_spec.to_hash, con_spec.connector_name)
    end

    def release_connection
      if _spec
        pool = @connection_handler.pool_for_spec(_spec)
        pool && pool.release_connection
      end
    end

    def connection_spec(request)
      @connection_specs[request] ||= @config.connection_spec(request)
    end
  end
end
