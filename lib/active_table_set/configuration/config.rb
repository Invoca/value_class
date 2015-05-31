# TODO -- (Later) Specify named timeout values, disallow arbitrary values  For example :web, 110 seconds,  :bulk = 15 minutes... :ringswitch_event_processor - 1 second.   :ringswitch_deferred - 15 seconds
# TODO -- (later) Add description for all config parameters.

module ActiveTableSet
  module Configuration
    class Config < DatabaseConnection
      include ValueClass::Constructable
      value_attr      :enforce_access_policy, default: false
      value_attr      :environment

# TODO - rename to default
      value_attr      :default_connection,   class_name: 'ActiveTableSet::Configuration::UsingSpec', required: true
      value_list_attr :table_sets,           class_name: 'ActiveTableSet::Configuration::TableSet', insert_method: :table_set
      value_list_attr :test_scenarios,       class_name: 'ActiveTableSet::Configuration::TestScenario', insert_method: :test_scenario

# TODO - tests around this attribute (I am adding this in response to other borken tests)
      attr_reader :default_request

      def initialize(options={})
        super
        table_sets.any? or raise ArgumentError, "no table sets defined"
        @table_sets_by_name     = table_sets.inject({}) { |memo, ts| memo[ts.name] = ts; memo }
        @test_scenarios_by_name = test_scenarios.inject({}) { |memo, ts| memo[ts.scenario_name] = ts; memo }

        @default_request = ActiveTableSet::Configuration::UsingSpec.new(
            table_set:     default_connection.table_set || table_sets.first.name,
            access_mode:   default_connection.access_mode || :write,
            partition_key: default_connection.partition_key,
            timeout: default_connection.timeout || 110, # TODO - use first named timeout
            test_scenario: default_connection.test_scenario
        )
      end

      def connection_spec(using_params)
        ts = @table_sets_by_name[using_params.table_set] or raise ArgumentError, "Unknown table set #{using_params.table_set}, available_table_sets: #{@table_sets_by_name.keys.sort.join(", ")}"
        spec = ts.connection_spec(using_params, [self], environment)

        if using_params.test_scenario
          raise "Not worthy!"
        end
        spec
      end

      def database_configuration
        result = {}

        default_config = connection_spec(default_request)

        result[environment] = default_config.specification.to_hash

        table_sets.each do |ts|
          ts.partitions.each_with_index do |part, index|
            prefix =
                if ts.partitioned?
                  "#{environment}_#{ts.name}_#{part.partition_key}"
                else
                  "#{environment}_#{ts.name}"
                end

            result["#{prefix}_leader"] = part.leader.connection_specification(alternates:[ts,part,self], timeout: default_request.timeout).to_hash

            part.followers.each_with_index do |follower, index|
              result["#{prefix}_follower_#{index}"] = follower.connection_specification(alternates:[ts,part,self], timeout: default_request.timeout).to_hash
            end
          end
        end

        test_scenarios.each do |ts|
          result["#{environment}_test_scenario_#{ts.scenario_name}"] = ts.connection_specification(alternates:[self], timeout: default_request.timeout).to_hash
        end
        result
      end

      def specification(user: :read_write)
        ActiveSupport::HashWithIndifferentAccess.new(
            "database"        => database,
            "connect_timeout" => connect_timeout,
            "read_timeout"    => timeout,
            "write_timeout"   => timeout,
            "encoding"        => encoding,
            "collation"       => collation,
            "adapter"         => adapter,
            "pool"            => pool_size,
            "reconnect"       => reconnect,
            "host"            => host,
            "username"        => (user == :read_write ? read_write_username : read_only_username),
            "password"        => (user == :read_write ? read_write_password : read_only_password),
        )
      end
    end

  end
end