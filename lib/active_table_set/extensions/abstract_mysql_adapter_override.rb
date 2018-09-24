# frozen_string_literal: true

module ActiveTableSet
  module Extensions
    module AbstractMysqlAdapterOverride
      def execute(sql, name = nil)
        skip_logging = name == :skip_logging
        if skip_logging
          non_nil_connection.query(sql)
        else
          log(sql, name) { non_nil_connection.query(sql) }
        end
      rescue ActiveRecord::StatementInvalid => exception
        first_message = exception.message.split(":").first
        if first_message =~ /Packets out of order/
          raise ActiveRecord::StatementInvalid, "'Packets out of order' error was received from the database. Please update your mysql bindings (gem install mysql) and read http://dev.mysql.com/doc/mysql/en/password-hashing.html for more information. If you're on Windows, use the Instant Rails installer to get the updated mysql bindings."
        elsif first_message =~ /Lock wait timeout exceeded/
          unless skip_logging
            log_mysql_status_context
          end
          raise
        else
          raise
        end
      end

      def update_sql(sql, name = nil) #:nodoc:
        @connection = non_nil_connection
        super
      end

      private

      def log_mysql_status_context
        # Not a recursive `execute` because for fear of causing an exception loop
        ["SHOW ENGINE INNODB STATUS;", "SHOW FULL PROCESSLIST;"].each do |sql|
          log(sql) { non_nil_connection.query(sql) }
        end
      end
    end
  end
end
