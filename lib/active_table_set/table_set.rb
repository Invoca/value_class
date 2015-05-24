module ActiveTableSet
  class TableSet
    include ValueClass::Constructable

    config_attribute      :name
    config_attribute      :access_policy,  class_name: 'ActiveTableSet::AccessPolicy', default: {}
    config_list_attribute :partitions,     class_name: 'ActiveTableSet::Partition', insert_method: :add_partition

    # TODO - construct a map of partitions by key
    def initialize(options = {})
      super
      partitions.count > 0 or raise ArgumentError, "must provide one or more partitions"
    end

    # TODO - I think the empty value should be nil
    def connection_key(access_mode: :write, partition_id: 0)
      partition_id <= (partitions.count - 1) or raise ArgumentError, "partition_id does not have a matching partition (id too big)"
      partitions[partition_id].connection_key(access_mode: access_mode)
    end
  end
end
