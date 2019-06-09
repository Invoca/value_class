# frozen_string_literal: true

module ActiveTableSet
  module Configuration
    class Partition < DatabaseConnection
      value_attr      :partition_key
      value_attr      :leader,    class_name: 'ActiveTableSet::Configuration::DatabaseConnection'
      value_list_attr :followers, class_name: 'ActiveTableSet::Configuration::DatabaseConnection', insert_method: 'follower'

      def initialize(options = {})
        super
        leader or raise ArgumentError, "must provide a leader"

        # Balanced - choose a follower randomly - once per partition instance
        available_database_configs = [leader] + followers
        selected_index            = self.class.random_database_config_index(available_database_configs.count)
        @balanced_config          = available_database_configs[selected_index]
        @balanced_config_failover = selected_index > 0 ? leader          : nil
        @follower_config          = followers.any?     ? followers.first : leader
      end

      def connection_attributes(request, database_connections, connection_name_prefix, access_policy)
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

      class << self
        def random_database_config_index(config_count)
          rand(config_count)
        end
      end
    end
  end
end
