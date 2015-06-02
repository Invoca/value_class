# TODO: (last) Add description for all config parameters.
# TODO: (last) Update readme

module ActiveTableSet
  module Configuration
    class Config < DatabaseConnection
      include ValueClass::Constructable
      value_attr      :enforce_access_policy, default: false
      value_attr      :environment

      value_attr      :default,        class_name: 'ActiveTableSet::Configuration::Request', required: true
      value_list_attr :table_sets,     class_name: 'ActiveTableSet::Configuration::TableSet', insert_method: :table_set
      value_list_attr :test_scenarios, class_name: 'ActiveTableSet::Configuration::TestScenario', insert_method: :test_scenario
      value_list_attr :timeouts,       class_name: 'ActiveTableSet::Configuration::NamedTimeout', insert_method: :timeout

      def initialize(options = {})
        super
        table_sets.any? or raise ArgumentError, "no table sets defined"
        @table_sets_by_name     = table_sets.inject({})     { |memo, ts| memo[ts.name] = ts; memo }
        @test_scenarios_by_name = test_scenarios.inject({}) { |memo, ts| memo[ts.scenario_name] = ts; memo }
        @timeouts_by_name       = timeouts.inject({})       { |memo, to| memo[to.name] = to; memo }

        # Fill in any empty values for default
        @default = @default.merge(
          table_set:     table_sets.first.name,
          access:        :leader,
          timeout:       (timeouts.first && timeouts.first.timeout) || 110
        )
      end

      def connection_spec(initial_request)
        request = convert_timeouts(initial_request)

        ts = @table_sets_by_name[request.table_set] or raise ArgumentError, "Unknown table set #{request.table_set}, available_table_sets: #{@table_sets_by_name.keys.sort.join(', ')}"
        spec = ts.connection_spec(request, [self], environment)

        if request.test_scenario
          scenario = @test_scenarios_by_name[request.test_scenario] or raise ArgumentError, "Unknown test_scenario #{request.test_scenario}, available test scenarios: #{@test_scenarios_by_name.keys.sort.join(', ')}"

          scenario.connection_spec(request, [self], environment, spec)
        else
          spec
        end
      end

      def database_configuration
        result = {}

        default_config = connection_spec(default)

        result[environment] = default_config.pool_key.to_hash

        table_sets.each do |ts|
          ts.partitions.each_with_index do |part, _index|
            prefix =
                if ts.partitioned?
                  "#{environment}_#{ts.name}_#{part.partition_key}"
                else
                  "#{environment}_#{ts.name}"
                end

            result["#{prefix}_leader"] = part.leader.pool_key(alternates: [ts, part, self], timeout: default.timeout).to_hash

            part.followers.each_with_index do |follower, index|
              result["#{prefix}_follower_#{index}"] = follower.pool_key(alternates: [ts, part, self], timeout: default.timeout).to_hash
            end
          end
        end

        test_scenarios.each do |ts|
          result[ts.scenario_name] = ts.pool_key(alternates: [self], timeout: default.timeout).to_hash
        end
        result
      end

      def convert_timeouts(initial_request)
        if @timeouts_by_name[initial_request.timeout]
          initial_request.merge(timeout: @timeouts_by_name[initial_request.timeout].timeout)
        else
          initial_request
        end
      end
    end
  end
end
