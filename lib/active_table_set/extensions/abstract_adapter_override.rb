module ActiveTableSet
  module Extensions
    module AbstractAdapterOverride
      def initialize(connection, logger = nil, pool = nil) #:nodoc:
        super
        @rows_read = []
      end

      def reset_rows_read
        rows_read, @rows_read = @rows_read, []
        rows_read
      end

      protected

      def connection=(new_connection)
        @connection = new_connection
        @connection_set_caller = caller.presence
      end

      def non_nil_connection
        @connection or raise "Connection is nil! It was assigned by:\n#{(@connection_set_caller || ['<none>']).join("\n")}"
      end

      def log(sql, name = "SQL", binds = [])
        @instrumenter.instrument(
            "sql.active_record",
            hash = {
                sql:            sql,
                name:           name,
                connection_id:  object_id,
                binds:          binds
            }
        ) do
          yield.tap do |result|
            hash[:rows] = result.count if result.respond_to?(:count)
            hash[:last_id] = @connection.last_id if @connection.respond_to?(:last_id) && @connection.last_id > 0
          end
        end
      rescue Exception => e
        message = "#{e.class.name}: #{e.message}: #{sql}"
        @logger.debug(message) if @logger
        exception = translate_exception(e, message)
        exception.set_backtrace(e.backtrace)
        raise exception
      end
    end
  end
end
