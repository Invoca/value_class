# TODO: quarantine
# TODO: failback
# TODO: only allow named timeouts

module ActiveTableSet
  class ConnectionManager

    def initialize(config:, pool_manager:)
      @config           = config
      @pool_manager     = pool_manager
      @connection_specs = {}
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

    def connection
      unless _connection
        establish_connection
      end
      _connection
    end

    private

    include ValueClass::ThreadLocalAttribute
    thread_local_instance_attr :_connection
    thread_local_instance_attr :_request
    thread_local_instance_attr :_pool
    thread_local_instance_attr :_access_lock

    def request
      self._request ||= @config.default
    end

    def yield_with_new_access_policy(new_request)
      old_request   = _request
      self._request = new_request
      set_connection_access_policy

      yield

    ensure
      self._request = old_request
      set_connection_access_policy
    end

    def yield_with_new_connection(new_request)
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
      self._pool       = @pool_manager.get_pool(key: connection_spec(request).pool_key)

      # The pool tests the connection when it is retrieved.
      self._connection = (_pool && _pool.connection) or raise ActiveRecord::ConnectionNotEstablished

      set_connection_extension
      set_connection_access_policy
    end

    def set_connection_extension
      unless connection.respond_to?(:using)
        connection.class.send(:include, ActiveTableSet::Extensions::ConvenientDelegation)
      end
    end

    def set_connection_access_policy
      if @config.enforce_access_policy
        unless connection.respond_to?(:access_policy)
          ActiveTableSet::Extensions::MysqlConnectionMonitor.install(connection)
        end
        connection.access_policy = connection_spec(request).access_policy
      end
    end

    def release_connection
      # We can end up with a nil pool if we cannot establish a connection.
      _pool && _pool.release_connection

      self._pool       = nil
      self._connection = nil
    end

    def connection_spec(request)
      @connection_specs[request] ||= @config.connection_spec(request)
    end
  end
end
