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
        @balanced_config_failover =
          if selected_index > 0
            leader
          else
            nil
          end

        # follower - use the first follower if there are any followers.
        @follower_config =
          if followers.any?
            followers.first
          else
            leader
          end
      end

      def connection_spec(request, database_connections, connection_name_prefix, access_policy)
        selected_config = configs_for_access(request.access)

        ConnectionAttributes.new(
          pool_key:          pool_key(selected_config.first, connection_name_prefix, database_connections, request),
          access_policy:     access_policy,
          failover_pool_key: selected_config.last && pool_key(selected_config.last, "#{connection_name_prefix}_failover_#{request.access}", database_connections, request)
        )
      end

      private

      def pool_key(config, context, database_connections, request)
        config.pool_key(
          alternates: [self] + database_connections,
          context: context,
          access: request.access,
          timeout: request.timeout
        )
      end

      def configs_for_access(access)
        case access
        when :leader
          [leader, nil]
        when :follower
          [@follower_config, nil]
        when :balanced
          [@balanced_config, @balanced_config_failover]
        else
          raise "We should not get here because access checks limit values.  What happened?"
        end
      end

      def self.pid
        $$
      end
    end
  end
end
