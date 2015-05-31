module ActiveTableSet
  module Configuration
    class Partition < DatabaseConnection
      value_attr      :partition_key
      value_attr      :leader,    class_name: 'ActiveTableSet::Configuration::DatabaseConnection'
      value_list_attr :followers, class_name: 'ActiveTableSet::Configuration::DatabaseConnection', insert_method: 'follower'

      def initialize(options={})
        super
        leader or raise ArgumentError, "must provide a leader"

        # Choose a follower based on the process id
        available_database_configs = [leader] + followers
        selected_index = self.class.pid % (available_database_configs.count)
        @chosen_follower = available_database_configs[selected_index]
      end

      # TODO - using_params or using_spec
      def connection_spec(using_params, database_connections, connection_name_prefix, access_policy)
        context = "#{connection_name_prefix}_#{using_params.access_mode}"
        selected_config =
            case using_params.access_mode
            when :write, :read
              leader
            when :balanced
              @chosen_follower
            else
              raise ArgumentError, "unknown access_mode #{using_params.access_mode}"
            end

        specification = selected_config.connection_specification(
            alternates: [self] + database_connections,
            context: context,
            access_mode: using_params.access_mode
        )

        ConnectionSpec.new(
           specification:   specification,
           access_policy:   access_policy,
           timeout:         using_params.timeout,
           connection_name: context
        )
      end

      def self.pid
        $$
      end
    end
  end
end