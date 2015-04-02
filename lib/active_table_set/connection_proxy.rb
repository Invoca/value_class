#
# The ConnectionProxy does 3 different things:
# 1. Maintains the tree of TableSets => Partitions => PoolKeys which it uses to retrieve the appropriate pool key.
# 2. Has a PoolManager. It passes pool keys to the pool manager and gets connections back.
# 3. Maintains variables to track which thread is active so that connections are not shared between threads.
#

module ActiveTableSet
  class ConnectionProxy

    def initialize(config:)
      @config = config
      @table_sets = build_table_sets(config)
    end

    def table_set_names
      table_sets.keys
    end

    private

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
