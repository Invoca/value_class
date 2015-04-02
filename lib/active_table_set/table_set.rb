module ActiveTableSet
  class TableSet
    attr_reader :partitions

    def initialize(config:)
      config.partition_count > 0 or raise ArgumentError, "must provide config information for one or more partitions"

      @partitions = config.partitions.map.with_index { |part, index|
        Partition.new(leader_key: part.leader_key, follower_keys: part.follower_keys, index: index)
      }

      @writable_tables = config.writeable_tables
      @readable_tables = config.readable_tables
    end

    def connection_key(access_mode: :write, partition_id: 0)
      partition_id <= (partitions.count - 1) or raise ArgumentError, "partition_id does not have a matching partition (id too big)"
      partitions[partition_id].connection_key(access_mode: access_mode)
    end

    def writeable_tables
      @writable_tables
    end

    def readable_tables
      @readable_tables
    end
  end
end
