# frozen_string_literal: true

module ActiveTableSet
  module Extensions
    module AbstractMysqlAdapterOverride
      def execute(sql, name = nil)
        if name == :skip_logging
          non_nil_connection.query(sql)
        else
          log(sql, name) { non_nil_connection.query(sql) }
        end
      rescue ActiveRecord::StatementInvalid => exception
        if exception.message.split(":").first =~ /Packets out of order/
          raise ActiveRecord::StatementInvalid, "'Packets out of order' error was received from the database. Please update your mysql bindings (gem install mysql) and read http://dev.mysql.com/doc/mysql/en/password-hashing.html for more information. If you're on Windows, use the Instant Rails installer to get the updated mysql bindings."
        else
          raise
        end
      end

      def update_sql(sql, name = nil) #:nodoc:
        @connection = non_nil_connection
        super
      end
    end
  end
end
