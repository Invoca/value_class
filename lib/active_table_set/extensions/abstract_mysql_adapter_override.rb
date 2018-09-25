# frozen_string_literal: true

module ActiveTableSet
  module Extensions
    module AbstractMysqlAdapterOverride
      def execute(sql, name = nil)
        execute_internal(sql, name)
      rescue ActiveRecord::StatementInvalid => exception
        message = exception.message
        if message =~ /Packets out of order/
          raise ActiveRecord::StatementInvalid, "'Packets out of order' error was received from the database. Please update your mysql bindings (gem install mysql) and read http://dev.mysql.com/doc/mysql/en/password-hashing.html for more information. If you're on Windows, use the Instant Rails installer to get the updated mysql bindings."
        elsif message =~ /Lock wait timeout exceeded/
          raise exception.class, "#{exception.message}\n\n#{mysql_status_context(name)}"
        else
          raise
        end
      end

      def update_sql(sql, name = nil) #:nodoc:
        @connection = non_nil_connection
        super
      end

      private

      def execute_internal(sql, name = nil)
        if name == :skip_logging
          non_nil_connection.query(sql)
        else
          log(sql, name) { non_nil_connection.query(sql) }
        end
      end

      def mysql_status_context(name = nil)
        # Not a recursive `execute` because for fear of causing an exception loop
        ["SHOW ENGINE INNODB STATUS;", "SHOW FULL PROCESSLIST;"].map do |sql|
          execute_internal(sql, name).to_csv
        end.join("\n\n")
      end
    end
  end
end
