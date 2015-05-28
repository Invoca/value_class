module ActiveTableSet
  module Extensions
    module MysqlConnectionMonitor
      attr_accessor :access_policy

      def self.install(connection)
        connection.extend(self)
      end

      class ActiveTableSet::AccessNotAllowed < ArgumentError; end

      def execute(query, name)
        if access_policy
          qp = ActiveTableSet::QueryParser.new(query)

          access_errors = access_policy.errors(write_tables: qp.write_tables, read_tables: qp.read_tables)
          if access_errors.any?
            raise ActiveTableSet::AccessNotAllowed, [
                                                      "Query denied by Active Table Set access_policy: (are you using the correct table set?)",
                                                      in_bars("   access_policy    ", access_policy.access_rules),
                                                      in_bars("       errors       ", access_errors),
                                                      in_bars("        query       ", query)
                                                  ].join("\n")
          end
        end
        super
      end

      private
      def in_bars(header,string_or_array)
        ("="*30) + header + ("="*30) + "\n" +
            [string_or_array].flatten.join("\n") + "\n" +
            ("="*80) + "\n"
      end
    end
  end
end

