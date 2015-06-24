module ActiveTableSet
  module Extensions
    module ConnectionHandlerExtension
      def self.prepended(klass)
        klass.send(:include, ValueClass::ThreadLocalAttribute)
        klass.thread_local_instance_attr :thread_connection_spec
      end

      # Overwrites the connection handler method.
      # Prefers the pool for the current spec, if any.
      def retrieve_connection_pool(klass)
        (thread_connection_spec && pool_for_spec(thread_connection_spec)) || super
      end

      # Overwrites the connection handler method.
      # Extends the connection class if needed.
      def retrieve_connection(klass)
        connection = super

        unless connection.respond_to?(:using)
          connection.class.send(:include, ActiveTableSet::Extensions::ConvenientDelegation)
        end

        if ActiveTableSet.enforce_access_policy? && !connection.respond_to?(:show_error_in_bars)
          connection.extend(ActiveTableSet::Extensions::MysqlConnectionMonitor)
        end

        connection
      end

      def default_spec(spec)
        @class_to_pool["ActiveRecord::Base"] = pool_for_spec(spec)
      end

      def current_spec= (spec)
        pool_for_spec(spec)
        self.thread_connection_spec = spec
      end

      def pool_for_spec(spec)
        @connection_pools[spec.config.dup] ||= ActiveRecord::ConnectionAdapters::ConnectionPool.new(spec.dup)
      end
    end
  end
end
