require 'active_record'

module ActiveTableSet
  class DatabaseServer
    attr_accessor :db_config, :server_type, :pool_manager

    def initialize(db_config: nil, server_type: nil, pool_manager: nil)
      db_config    or raise "Must pass a configuration"
      server_type  or raise "Must pass a type"
      pool_manager or raise "Must pass a pool manager"

      @db_config    = db_config
      @server_type  = server_type
      @pool_manager = pool_manager
    end

    def connection_name
      "#{server_type}_connection"
    end

  end
end
