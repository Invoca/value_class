require 'active_record'

module ActiveTableSet
  class PoolManager
    include ActiveRecord::ConnectionAdapters

    def initialize
      @pools = Hash.new
    end

    def get_pool(key:)
      key or raise "Must provide a DatabaseConfig in order to get a pool"
      @pools[key] ||= create_pool(key)
    end

# TODO - Get rid of these methods (tests only)
    def destroy_pool(key:)
      @pools.delete(key)
    end

    def pool_count
      @pools.length
    end

    def create_pool(config)
      ActiveRecord::ConnectionAdapters::ConnectionPool.new(specification(config))
    end

    def specification(config)
      ActiveRecord::Base::ConnectionSpecification.new(config.specification, config.name)
    end
  end
end
