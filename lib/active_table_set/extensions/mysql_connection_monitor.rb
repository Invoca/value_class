# Need better name
module ActiveTableSet
  module Extensions
    module MysqlConnectionMonitor
      class ActiveTableSet::AccessNotAllowed < ArgumentError; end

      def execute(query, name)
        if access_policy = ActiveTableSet.access_policy
          qp = ActiveTableSet::QueryParser.new(query)

          access_errors = access_policy.errors(write_tables: qp.write_tables, read_tables: qp.read_tables)
          if access_errors.any?
            raise ActiveTableSet::AccessNotAllowed, [
              "Query denied by Active Table Set access_policy: (are you using the correct table set?)",
              show_error_in_bars("   access_policy    ", access_policy.access_rules),
              show_error_in_bars("       errors       ", access_errors),
              show_error_in_bars("        query       ", query)
            ].join("\n")
          end
        end
        super
      end

      def show_error_in_bars(header, string_or_array)
        ("=" * 30) + header + ("=" * 30) + "\n" +
          [string_or_array].flatten.join("\n") + "\n" +
          ("=" * 80) + "\n"
      end
    end
  end
end
