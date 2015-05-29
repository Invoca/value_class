# TODO -- (Later) Specify named timeout values, disallow arbitrary values  For example :web, 110 seconds,  :bulk = 15 minutes... :ringswitch_event_processor - 1 second.   :ringswitch_deferred - 15 seconds
# TODO -- (later) Define users outside of DB spec?
# TODO -- (later) Add description for all config parameters.

# TODO - the default connection should allow a test scenario

module ActiveTableSet
  module Configuration
    class Config
      include ValueClass::Constructable

      value_attr      :enforce_access_policy, default: false
      value_attr      :environment
      value_attr      :default_connection,   class_name: 'ActiveTableSet::Configuration::DefaultConnection', required: true
      value_list_attr :table_sets,           class_name: 'ActiveTableSet::Configuration::TableSet', insert_method: :table_set
      value_list_attr :test_scenarios,       class_name: 'ActiveTableSet::Configuration::TestScenario', insert_method: :test_scenario

      def initialize(options={})
        super
        table_sets.any? or raise ArgumentError, "no table sets defined"
        @table_sets_by_name     = table_sets.inject({}) { |memo, ts| memo[ts.name] = ts; memo }
        @test_scenarios_by_name = test_scenarios.inject({}) { |memo, ts| memo[ts.scenario_name] = ts; memo }
      end

      # TODO - This set of parameters may be the same as default_connection.
      def database_config(table_set:, access_mode:, partition_key:, test_scenario:)
        if test_scenario
          ts = @test_scenarios_by_name[test_scenario] or raise ArgumentError, "Unknown test scenario #{test_scenario}, available_table_sets: #{@test_scenarios_by_name.keys.sort.join(", ")}"
        else
          ts = @table_sets_by_name[table_set] or raise ArgumentError, "Unknown table set #{table_set}, available_table_sets: #{@table_sets_by_name.keys.sort.join(", ")}"
          ts.database_config(access_mode: access_mode, partition_key: partition_key)
        end
      end

      def database_configuration
        result = {}

        default_config = database_config(
            table_set: default_connection.table_set,
            access_mode: default_connection.access_mode,
            partition_key: default_connection.partition_key,
            test_scenario: nil
        )

        result[environment] = default_config.specification

        table_sets.each do |ts|
          ts.partitions.each_with_index do |part, index|
            prefix =
                if ts.partitioned?
                  "#{environment}_#{ts.name}"
                else
                  "#{environment}_#{ts.name}_#{part.partition_key}"
                end

            result["#{prefix}_leader"] = part.leader.specification

            part.followers.each_with_index do |follower, index|
              result["#{prefix}_follower_#{index}"] = follower.specification
            end
          end
        end

        test_scenarios.each do |ts|
          result["#{environment}_test_scenario_#{ts.scenario_name}"] = ts.specification
        end
        result
      end
    end
  end
end