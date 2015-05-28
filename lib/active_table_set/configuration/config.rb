# TODO -- (Later) Specify named timeout values, disallow arbitrary values  For example :web, 110 seconds,  :bulk = 15 minutes... :ringswitch_event_processor - 1 second.   :ringswitch_deferred - 15 seconds
# TODO -- (later) Define users outside of DB spec?
# TODO -- (later) Add description for all config parameters.

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

      def database_config(table_set:, access_mode:, partition_key:, test_scenario:)
        if test_scenario
          ts = @test_scenarios_by_name[test_scenario] or raise ArgumentError, "Unknown test scenario #{test_scenario}, available_table_sets: #{@test_scenarios_by_name.keys.sort.join(", ")}"
        else
          ts = @table_sets_by_name[table_set] or raise ArgumentError, "Unknown table set #{table_set}, available_table_sets: #{@table_sets_by_name.keys.sort.join(", ")}"
          ts.database_config(access_mode: access_mode, partition_key: partition_key)
        end
      end

      def all_database_configurations
        table_sets.map do |ts|
          ts.partitions.map do |part|
            ([part.leader] + part.followers).map { |dc| dc.specification }
          end
        end.flatten.uniq
      end
    end
  end
end