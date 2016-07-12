module ActiveTableSet
  module Extensions
    module Mysql2AdapterOverride
      attr_reader :config

      def quote_string(string)
        non_nil_connection.escape(string)
      end

      def insert_sql(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil)
        super
        id_value || non_nil_connection.last_id
      end
      alias :create :insert_sql

      def exec_delete(sql, name, binds)
        execute to_sql(sql, binds), name
        non_nil_connection.affected_rows
      end
      alias :exec_update :exec_delete

      def last_inserted_id(result)
        non_nil_connection.last_id
      end

      private
        def configure_connection
          non_nil_connection.query_options.merge!(:as => :array)

          # By default, MySQL 'where id is null' selects the last inserted id.
          # Turn this off. http://dev.rubyonrails.org/ticket/6778
          variable_assignments = ['SQL_AUTO_IS_NULL=0']
          encoding = @config[:encoding]

          # make sure we set the encoding
          variable_assignments << "NAMES '#{encoding}'" if encoding

          # increase timeout so mysql server doesn't disconnect us
          wait_timeout = @config[:wait_timeout]
          wait_timeout = 2147483 unless wait_timeout.is_a?(Fixnum)
          variable_assignments << "@@wait_timeout = #{wait_timeout}"

          execute("SET #{variable_assignments.join(', ')}", :skip_logging)
        end

        def version
          @version ||= non_nil_connection.info[:version].scan(/^(\d+)\.(\d+)\.(\d+)/).flatten.map { |v| v.to_i }
        end
    end
  end
end
