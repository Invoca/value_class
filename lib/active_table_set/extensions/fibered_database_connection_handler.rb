module ActiveTableSet
  module Extensions
    module FiberedDatabaseConnectionHandler
      # from Rails active_record/connection_adapters/abstract/connection_pool.rb:512
      def establish_connection(owner, spec)
        owner.name or raise RuntimeError, "Anonymous class is not allowed."
        @class_to_pool.clear
        owner_to_pool[owner.name] =
            if spec.config[:adapter] == "em_mysql2"
              FiberedDatabaseConnectionPool.new(spec)
            else
              ActiveRecord::ConnectionAdapters::ConnectionPool.new(spec)
            end
      end
    end
  end
end
