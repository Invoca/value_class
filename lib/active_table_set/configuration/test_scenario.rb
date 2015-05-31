module ActiveTableSet
  module Configuration
    class TestScenario < DatabaseConnection
      value_attr :scenario_name, required: true

      # TODO - need timeout here.

      def connection_spec(request, database_connections, connection_name_prefix, previous_spec)
        context = "#{connection_name_prefix}_#{scenario_name}"

        specification = connection_specification(
          alternates:  database_connections,
          context:     context,
          access_mode: :write,
          timeout:     110 # TODO - what timeout?
        )

        ConnectionSpec.new(
          specification:   specification,
          access_policy:   previous_spec.access_policy,
          connection_name: context
        )
      end

    end
  end
end
