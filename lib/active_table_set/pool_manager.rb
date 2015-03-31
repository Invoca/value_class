require 'active_record'
require 'active_support/version'
require 'active_support/core_ext/class'

module ActiveTableSet
  class PoolManager
    include ActiveRecord::ConnectionAdapters

    def initialize
      @pools = Hash.new
    end

    def get_pool(key: nil, config: nil)
      key or raise "Must provide a PoolKey to request a pool"
      @pools[key] ||= create_pool(config)
    end

    def destroy_pool(key: nil)
      key or raise "Must provide a PoolKey to destroy a pool"
      @pools.delete(key)
    end

    def pool_count
      @pools.length
    end

    private

    def create_pool(config)
      config or raise "Must provide a DatabaseConfig in order to create a ConnectionPool"
      ActiveRecord::ConnectionAdapters::ConnectionPool.new(specification(config))
    end

    def specification(config)
      config or raise "Must provide a DatabaseConfig in order to create a ConnectionSpecification"
      ActiveRecord::Base::ConnectionSpecification.new(config.specification, config.name)
    end
  end
end
