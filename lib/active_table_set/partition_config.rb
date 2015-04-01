require 'active_support/hash_with_indifferent_access'

module ActiveTableSet
  class PartitionConfig
    include ActiveSupport

    def initialize(partition_hash:)
      @leader    = build_database_config(partition_hash[:leader])
      @followers = partition_hash[:followers].map { |h| build_database_config(h) }
    end

    def leader_key
      leader.pool_key
    end

    def follower_keys
      followers.map { |f| f.pool_key }
    end

    private

    def leader
      @leader
    end

    def followers
      @followers
    end

    def build_database_config(config_hash)
      ActiveTableSet::DatabaseConfig.new(
        database: config_hash[:database],
        timeout:  config_hash[:timeout],
        host:     config_hash[:host],
        username: config_hash[:username],
        password: config_hash[:password]
      )
    end
  end
end
