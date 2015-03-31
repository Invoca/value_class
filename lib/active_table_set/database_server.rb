require 'active_record'

module ActiveTableSet
  class DatabaseServer
    attr_accessor :db_config, :server_type

    def initialize(db_config: nil, server_type: nil, pool_manager: nil)
      db_config    or raise "Must pass a configuration"
      server_type  or raise "Must pass a type"
      pool_manager or raise "Must pass a pool manager"

      @db_config    = db_config
      @server_type  = server_type
      @pool_manager = pool_manager
    end

    def connection
      (pool && pool.connection) or raise ActiveRecord::ConnectionNotEstablished
    end

    def release_connection
      pool && pool.release_connection
    end

    def disconnect!
      release_connection
      pool && pool.disconnect!
    end

    private

    def pool
      @pool ||= pool_manager.get_pool(key: db_config.pool_key, config: db_config)
    end
  end
end
