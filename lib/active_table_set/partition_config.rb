module ActiveTableSet
  class PartitionConfig
    include ActiveTableSet::Configurable

    # TODO Need partition key, and need interface to use it.
    #config_attribute      :partition_key
    config_attribute      :leader,    class_name: 'ActiveTableSet::DatabaseConfig'
    config_list_attribute :followers, class_name: 'ActiveTableSet::DatabaseConfig'

    def leader_key
      leader.pool_key
    end

    def follower_keys
      followers.map { |f| f.pool_key }
    end
  end
end
