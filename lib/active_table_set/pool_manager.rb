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

    # TODO - insufficient tests
    def create_pool(config)
      ActiveRecord::ConnectionAdapters::ConnectionPool.new(specification(config))
    end

    # TODO - insufficient tests
    def specification(config)
      ActiveRecord::Base::ConnectionSpecification.new(config.to_hash, config.name)
    end
  end
end
