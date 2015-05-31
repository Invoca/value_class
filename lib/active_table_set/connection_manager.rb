module ActiveTableSet
  class ConnectionManager

    def initialize(config:, pool_manager: )
      @config       = config
      @pool_manager = pool_manager
    end

    def using(table_set: nil, access_mode: nil, partition_key: nil, timeout: nil, &blk)
      new_request = request.merge(
        table_set:     table_set,
        access_mode:   access_mode,
        partition_key: partition_key,
        timeout:       timeout
      )

      if new_request == request
        yield
      else
        # TODO - if in a test mode and the test scenario did not change, change the access rules
        yield_with_new_connection(new_request, &blk)
      end
    end

    def use_test_scenario(test_scenario_name)
      _connection or raise "unexpected - no existing connection"
      _request    or raise "unexpected - no existing request"

      new_request = request.merge(test_scenario: test_scenario_name)

      # TODO - this should not get new connections if the keys are different, but it will update the request.
      if new_request != request
        release_connection
        self._request = new_request
        establish_connection
      end
    end

    def connection
      unless _connection
        establish_connection
      end
      self._connection
    end


    private

    include ValueClass::ThreadLocalAttribute
    thread_local_instance_attr :_connection
    thread_local_instance_attr :_request
    thread_local_instance_attr :_pool

    def request
      self._request ||= @config.default
    end

    def yield_with_new_connection(new_request)
      _connection or raise "unexpected - no existing connection"
      _request    or raise "unexpected - no existing request"
      _pool       or raise "unexpected - no existing pool"

      old_request    = _request
      old_connection = _connection
      old_pool       = _pool

      self._request    = new_request
      self._connection = nil
      self._pool       = nil

      establish_connection

      yield

    ensure
      release_connection

      self._request    = old_request
      self._connection = old_connection
      self._pool       = old_pool
    end

    def establish_connection
      self._connection = "foo"
      self._pool = @pool_manager.get_pool(key: connection_spec.pool_key)

      connection = _pool.connection

      unless connection.respond_to?(:using)
        connection.class.send(:include, ActiveTableSet::Extensions::ConvenientDelegation)
      end

      if @config.enforce_access_policy
        if !connection.respond_to?(:access_policy)
          ActiveTableSet::Extensions::MysqlConnectionMonitor.install(connection)
        end
        connection.access_policy = connection_spec.access_policy
      end

      # TODO - test the connection
      # TODO - add access policy
      self._connection = connection
    end

    def release_connection
      self._pool.release_connection
      self._pool = nil
      self._connection = nil
    end

    def connection_spec
      @config.connection_spec(request)
    end

  end
end
