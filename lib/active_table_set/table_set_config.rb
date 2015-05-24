module ActiveTableSet
  class TableSetConfig
    include ActiveTableSet::Configurable

    config_attribute      :name
    config_attribute      :access_policy,  class_name: 'ActiveTableSet::AccessPolicy'
    config_list_attribute :partitions,     class_name: 'ActiveTableSet::PartitionConfig', insert_method: :add_partition
  end
end
