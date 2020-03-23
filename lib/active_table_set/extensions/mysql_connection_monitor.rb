# frozen_string_literal: true

# Need better name
module ActiveTableSet
  module Extensions
    module MysqlConnectionMonitor
      class ActiveTableSet::AccessNotAllowed < ArgumentError; end

      def execute(query, name = nil)
        check_query(query)
        super
      end

      def check_query(query)
        if access_policy = ActiveTableSet.access_policy
          qp = ActiveTableSet::QueryParser.new(query)
          access_errors = access_policy.errors(write_tables: qp.write_tables, read_tables: qp.read_tables)

          if access_errors.any?
            message = [
              "Query denied by Active Table Set access_policy: (are you using the correct table set?)",
              "Current settings: #{ActiveTableSet.manager.settings.to_hash.inspect}",
              show_error_in_bars("Errors", access_errors),
              show_error_in_bars("Access Policy", access_policy.access_rules),
              show_error_in_bars("Query", query)
            ].join("\n\n") + "\n"

            raise ActiveTableSet::AccessNotAllowed, message
          end
        end
      end

      def show_error_in_bars(header, string_or_array)
        lines = Array(string_or_array).flat_map { |s| s.split("\n") }
        header + "\n" + lines.map { |l| "    #{l}" }.join("\n")
      end
    end
  end
end
