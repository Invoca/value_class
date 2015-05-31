require 'active_support/core_ext'

# For the delegation trick
require 'active_record/connection_adapters/mysql2_adapter'

# The ConnectionProxy does 3 different things:
# 1. Maintains the tree of TableSets => Partitions => PoolKeys which it uses to retrieve the appropriate pool key.
# 2. Has a PoolManager. It passes pool keys to the pool manager and gets connections back.
# 3. Maintains variables to track which thread is active so that connections are not shared between threads.

# TODO -- wire up default connection
# TODO -- wire up enforce access policy
# TODO -- Get rid of delegation from connection proxy.  Instead, extend the class to add the syntax we want.
# TODO -- Wireup test scenarios
# TODO -- Wire up timeouts


module ActiveTableSet
  class ConnectionProxy
    delegate *(ActiveRecord::ConnectionAdapters::Mysql2Adapter.instance_methods - ActiveTableSet::ConnectionProxy.instance_methods), :to => :connection

    include ValueClass::ThreadLocalAttribute
    thread_local_instance_attr :thread_database_config
    thread_local_instance_attr :test_scenario

    def initialize(config:)
      @config       = config
      @pool_manager = ActiveTableSet::PoolManager.new
    end

    def using(table_set:, access_mode: :write, partition_key: 0, timeout: nil, &blk)
      new_key = timeout_adjusted_database_config(table_set, access_mode, partition_key, timeout)
      if new_key == thread_database_config
        yield
      else
        yield_with_new_connection(new_key, &blk)
      end
    end

    def connection
      if !thread_database_config
        self.thread_database_config = timeout_adjusted_database_config(
            @config.default.table_set,
            @config.default.access_mode,
            @config.default.partition_key,
            @config.default.timeout )
      end
      # TODO - Don't change connection unless the key changes...
      obtain_connection(thread_database_config)
    end


    # Prefer values from config...
    DEFAULT_ACCESS_MODE  = :write
    DEFAULT_PARTITION_ID = 0
    DEFAULT_TIMEOUT_SECS = 2

    def set_default_table_set(table_set_name:)
      thread_database_config.nil? or raise "Can not use set_default_table_set while in the scope of an existing table set - startup only bro"
      if thread_database_config
        release_connection(thread_database_config)
      end
      self.thread_database_config = timeout_adjusted_database_config(table_set_name, DEFAULT_ACCESS_MODE, DEFAULT_PARTITION_ID, DEFAULT_TIMEOUT_SECS)
    end

    private

    def yield_with_new_connection(new_key)
      old_key = thread_database_config
      self.thread_database_config = new_key
      obtain_connection(new_key)
      yield
    ensure
      release_connection(new_key)
      self.thread_database_config = old_key
    end

    ## CONNECTIONS ##

    def release_connection(key)
      if (pool = pool(key))
        pool.release_connection
      end
    end

    def obtain_connection(key)
      if (pool = pool(key))
        pool.connection
      else
        raise ActiveRecord::ConnectionNotEstablished
      end
    end

    ## DATABASE MANAGEMENT ##

    def database_config(table_set:, access_mode: :write, partition_key: nil, timeout: 50)
      using_spec = ActiveTableSet::Configuration::Request.new(
          table_set: table_set,
          access_mode: access_mode,
          partition_key: partition_key,
          test_scenario: nil,
          timeout: timeout
      )

       @config.connection_spec(using_spec).pool_key
    end

    # TODO - deprecated in favor of setting the timeout on a connection when passed out from the pool.
    def timeout_adjusted_database_config(table_set, access_mode, partition_key, timeout)
      database_config(table_set: table_set, access_mode: access_mode, partition_key: partition_key, timeout: timeout)
    end

    ## POOL MANAGER ##
    attr_reader :pool_manager

    def pool(key)
      pool_manager.get_pool(key: key)
    end
  end
end
