module ActiveTableSet
  module Configuration
    class TestScenario < DatabaseConnection
      value_attr :scenario_name, required: true

      # TODO - need timeout here.

      def connection_spec(request, database_connections, connection_name_prefix, previous_spec)
        context = "#{connection_name_prefix}_#{scenario_name}"

        pool_key = connection_specification(
          alternates:  database_connections,
          context:     context,
          access_mode: :write,
          timeout:     110 # TODO - what timeout?
        )

        ConnectionSpec.new(
          pool_key:        pool_key,
          access_policy:   previous_spec.access_policy,
          connection_name: context
        )
      end

    end
  end
end
