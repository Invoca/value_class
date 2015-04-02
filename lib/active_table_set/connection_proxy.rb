#
# The ConnectionProxy does 3 different things:
# 1. Maintains the tree of TableSets => Partitions => PoolKeys which it uses to retrieve the appropriate pool key.
# 2. Has a PoolManager. It passes pool keys to the pool manager and gets connections back.
# 3. Maintains variables to track which thread is active so that connections are not shared between threads.
#

module ActiveTableSet
  class ConnectionProxy

    def initialize(config:)
      @config       = config
      @table_sets   = build_table_sets(config)
      @pool_manager = PoolManager.new
    end

    def table_set_names
      table_sets.keys
    end

    def connection_key(table_set:, access_mode: :write, partition_id: 0)
      ts = table_sets[table_set] or raise ArgumentError, "pool key requested from unknown table set #{table_set}"
      ts.connection_key(access_mode: access_mode, partition_id: partition_id)
    end

    def pool(key:)
      pool_manager.get_pool(key: key)
    end

    private

    def pool_manager
      @pool_manager
    end

    def table_sets
      @table_sets
    end

    def build_table_sets(config)
      ts = config[:table_sets].map { |table_set| build_table_set(table_set) }
      Hash[*ts.flatten]
    end

    def build_table_set(config)
      [config[:name], ActiveTableSet::TableSet.new(config: ActiveTableSet::TableSetConfig.new(config: config))]
    end
  end
end
