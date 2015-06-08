# -*- coding: utf-8 -*-

module ActiveTableSet
  module Configuration
    class Partition < DatabaseConnection
      value_attr      :partition_key
      value_attr      :leader,    class_name: 'ActiveTableSet::Configuration::DatabaseConnection'
      value_list_attr :followers, class_name: 'ActiveTableSet::Configuration::DatabaseConnection', insert_method: 'follower'

      def initialize(options = {})
        super
        leader or raise ArgumentError, "must provide a leader"

        # Balanced - choose a follower based on the process id
        available_database_configs = [leader] + followers
        selected_index = self.class.pid % (available_database_configs.count)
        @balanced_config = available_database_configs[selected_index]

        # follower - use the first follower if there are any followers.
        @follower_config =
          if followers.any?
            followers.first
          else
            leader
          end
      end

      def connection_spec(request, database_connections, connection_name_prefix, access_policy)
        context = "#{connection_name_prefix}_#{request.access}"
        selected_config =
            case request.access
            when :leader
              leader
            when :follower
              @follower_config
            when :balanced
              @balanced_config
            else
              raise "We should not get here because access checks limit values.  What happened?"
            end

        # Now I need to change pool_key back to pool key
        pook_key = selected_config.pool_key(
          alternates: [self] + database_connections,
          context: context,
          access: request.access,
          timeout: request.timeout
        )

        ConnectionAttributes.new(
          pool_key:        pook_key,
          access_policy:   access_policy
        )
      end

      def self.pid
        $$
      end
    end
  end
end
