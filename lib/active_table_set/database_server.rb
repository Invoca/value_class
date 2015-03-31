require 'active_record'

module ActiveTableSet
  class DatabaseServer
    attr_reader :config, :server_type

    def initialize(config:, server_type:)
      @config      = config
      @server_type = server_type
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
      @pool ||= config.pool_manager.get_pool(key: db_config.pool_key, config: db_config)
    end
  end
end
