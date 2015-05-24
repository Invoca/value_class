module ActiveTableSet
  class TableSet
    attr_reader :partitions, :access_policy

    def initialize(config:)
      config.partitions.count > 0 or raise ArgumentError, "must provide config information for one or more partitions"

      @partitions = config.partitions.map.with_index { |part, index|
        ActiveTableSet::Partition.new(leader_key: part.leader_key, follower_keys: part.follower_keys, index: index)
      }

      @access_policy = config.access_policy
    end

    def connection_key(access_mode: :write, partition_id: 0)
      partition_id <= (partitions.count - 1) or raise ArgumentError, "partition_id does not have a matching partition (id too big)"
      partitions[partition_id].connection_key(access_mode: access_mode)
    end
  end
end
