# TODO: (last) Add description for all config parameters.
# TODO: (last) Update readme

# TODO: Allow class table sets...

module ActiveTableSet
  module Configuration
    class Config < DatabaseConnection
      include ValueClass::Constructable
      value_attr      :enforce_access_policy, default: false
      value_attr      :environment

      value_attr      :default,          class_name: 'ActiveTableSet::Configuration::Request', required: true
      value_list_attr :table_sets,       class_name: 'ActiveTableSet::Configuration::TableSet', insert_method: :table_set
      value_list_attr :test_scenarios,   class_name: 'ActiveTableSet::Configuration::TestScenario', insert_method: :test_scenario
      value_list_attr :timeouts,         class_name: 'ActiveTableSet::Configuration::NamedTimeout', insert_method: :timeout
      value_list_attr :class_table_sets, class_name: 'ActiveTableSet::Configuration::ClassTableSet', insert_method: :class_table_set

      value_attr      :default_test_scenario

      def initialize(options = {})
        super
        table_sets.any? or raise ArgumentError, "no table sets defined"
        @table_sets_by_name     = table_sets.inject({})     { |memo, ts| memo[ts.name] = ts; memo }
        @test_scenarios_by_name = test_scenarios.inject({}) { |memo, ts| memo[ts.scenario_name] = ts; memo }
        @timeouts_by_name       = timeouts.inject({})       { |memo, to| memo[to.name] = to; memo }

        !default_test_scenario || @test_scenarios_by_name[default_test_scenario] or raise ArgumentError, "default test scenario #{default_test_scenario} not found, availalable scenarios: #{@test_scenarios_by_name.keys.join(", ")}"

        # Fill in any empty values for default
        @default = ActiveTableSet::Configuration::Request.new(
          table_set:     table_sets.first.name,
          access:        :leader,
          timeout:       (timeouts.first && timeouts.first.timeout) || 110
        ).merge(@default)
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
        @database_configuration ||= _database_configuration
      end

      private

      ConfigStruct = Struct.new(:key, :value)

      def _database_configuration
        values_with_dups = [
          default_database_config,
          table_set_database_config,
          test_scenario_database_config
        ].flatten.compact


        values_with_dups.inject({}) do |memo, config|
          value = config.value.to_hash
          memo[config.key] = value unless memo.values.include?(value)
          memo
        end
      end

      def default_database_config
        ConfigStruct.new(environment, connection_spec(default).pool_key)
      end

      def table_set_database_config
        table_sets.map do |ts|
          partition_database_config(ts)
        end
      end

      def partition_database_config(ts)
        ts.partitions.map do |part|
          prefix =
            if ts.partitioned?
              "#{environment}_#{ts.name}_#{part.partition_key}"
            else
              "#{environment}_#{ts.name}"
            end

          # Need read only on leader.
          [ts_config(part.leader, "#{prefix}_leader", [ts, part, self])] + [ts_config(part.leader, "#{prefix}_leader_ro", [ts, part, self], access: :follower)] +
            part.followers.each_with_index.map { |follower, index| ts_config(follower, "#{prefix}_follower_#{index}", [ts, part, self]) }
        end
      end

      def ts_config(db_config, key, alternates, access: :leader)
        ConfigStruct.new(key, db_config.pool_key(alternates: alternates, access: access, timeout: default.timeout))
      end

      def test_scenario_database_config
        test_scenarios.map { |ts| ts_config(ts, ts.scenario_name, [self]) }
      end

# TODO: When passing a symbol to a timeout, confirm it exists with a meaningful error.
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
