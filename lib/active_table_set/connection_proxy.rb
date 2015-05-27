require 'active_support/core_ext'
# The ConnectionProxy does 3 different things:
# 1. Maintains the tree of TableSets => Partitions => PoolKeys which it uses to retrieve the appropriate pool key.
# 2. Has a PoolManager. It passes pool keys to the pool manager and gets connections back.
# 3. Maintains variables to track which thread is active so that connections are not shared between threads.

# TODO - move query timeouts out of the database key.   Do not keep separate pools for these, set connection when checked out.
# wire up default connection
# wire up enforce access policy


module ActiveTableSet
  class ConnectionProxy
    delegate *(ActiveRecord::ConnectionAdapters::Mysql2Adapter.instance_methods - ActiveTableSet::ConnectionProxy.instance_methods), :to => :connection

    THREAD_DB_database_config = :active_table_set_per_thread_database_config
    DEFAULT_ACCESS_MODE  = :write
    DEFAULT_PARTITION_ID = 0
    DEFAULT_TIMEOUT_SECS = 2

    def initialize(config:)
      @config       = config
      @table_sets   = build_table_sets(config)
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
      obtain_connection(thread_database_config)
    end

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

    ## THREAD SAFE KEYS ##

    def thread_database_config
      Thread.current.thread_variable_get(THREAD_DB_database_config)
    end

    def thread_database_config=(key)
      Thread.current.thread_variable_set(THREAD_DB_database_config, key)
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

    def database_config(table_set:, access_mode: :write, partition_key: nil)
      ts = table_sets[table_set] or raise ArgumentError, "pool key requested from unknown table set #{table_set}"
      ts.database_config(access_mode: access_mode, partition_key: partition_key)
    end

    def timeout_adjusted_database_config(table_set, access_mode, partition_key, timeout)
      key = database_config(table_set: table_set, access_mode: access_mode, partition_key: partition_key)
      timeout.nil? ? key : key.clone_with_new_timeout(timeout)
    end

    ## POOL MANAGER ##

    attr_reader :pool_manager

    def pool(key)
      pool_manager.get_pool(key: key)
    end

    ## TABLE SETS ##

    attr_reader :table_sets

    def table_set_names
      table_sets.keys
    end

    def build_table_sets(config)
      ts = config[:table_sets].keys.map { |ts_key| build_table_set(ts_key, config[:table_sets][ts_key]) }
      Hash[*ts.flatten]
    end

    def build_table_set(name, config)
      [name, ActiveTableSet::Configuration::TableSet.new(config)]
    end
  end
end
