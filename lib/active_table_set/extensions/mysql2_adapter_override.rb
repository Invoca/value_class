# frozen_string_literal: true

module ActiveTableSet
  module Extensions
    module Mysql2AdapterOverride
      attr_reader :config

      def quote_string(string)
        non_nil_connection.escape(string)
      end

      def insert_sql(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil)
        id_value ||= non_nil_connection.last_id
        super
      end

      def exec_delete(sql, name, binds)
        execute(to_sql(sql, binds), name)
        non_nil_connection.affected_rows
      end

      def last_inserted_id(result)
        non_nil_connection.last_id
      end

      private

      TIMEOUT_VARIALBES = [
        { "name" => :wait_timeout, "default_value" => 2147483 },
        { "name" => :net_read_timeout },
        { "name" => :net_write_timeout }
      ]

      def configure_connection
        non_nil_connection.query_options.merge!(as: :array)

        # By default, MySQL 'where id is null' selects the last inserted id.
        # Turn this off. http://dev.rubyonrails.org/ticket/6778
        variable_assignments = ['SQL_AUTO_IS_NULL=0']
        encoding = @config[:encoding]

        # make sure we set the encoding
        variable_assignments << "NAMES '#{encoding}'" if encoding

        # increase timeout so mysql server doesn't disconnect us
        variable_assignments += timeout_variable_assignments

        execute("SET #{variable_assignments.join(', ')}", :skip_logging)
      end

      def timeout_variable_assignments
        TIMEOUT_VARIALBES.map_compact do |timeout_variable_hash|
          timeout_variable_assignment(name: timeout_variable_hash["name"], default_value: timeout_variable_hash["default_value"])
        end
      end

      def timeout_variable_assignment(name:, default_value: nil)
        timeout_value = @config[name].is_a?(Integer) ? @config[name] : default_value
        if timeout_value
          "@@#{name} = #{timeout_value}"
        end
      end

      def version
        @version ||= non_nil_connection.info[:version].match(/^\d+\.\d+\.\d+/)[0]
      end
    end
  end
end
