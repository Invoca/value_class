# frozen_string_literal: true

module ActiveTableSet
  module Configuration
    class TestScenario < DatabaseConnection
      value_attr :scenario_name, required: true
      value_attr :timeout,       required: true, default: 110
      value_attr :net_read_timeout

      def connection_attributes(request, database_connections, connection_name_prefix, previous_spec)
        context = "#{connection_name_prefix}_#{scenario_name}"

        pool_key = pool_key(
          alternates:       database_connections,
          context:          context,
          access:           :leader,
          timeout:          timeout,
          net_read_timeout: request.net_read_timeout
        )

        ConnectionAttributes.new(
          pool_key:        pool_key,
          access_policy:   previous_spec.access_policy
        )
      end

    end
  end
end
