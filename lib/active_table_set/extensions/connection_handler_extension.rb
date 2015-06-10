module ActiveTableSet
  module Extensions
    module ConnectionHandlerExtension
      def self.prepended(klass)
        klass.send(:include, ValueClass::ThreadLocalAttribute)
        klass.thread_local_instance_attr :thread_connection_spec
        klass.send(:attr_accessor, :include_connection_monitoring)
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

        if include_connection_monitoring && connection.respond_to?(:show_error_in_bars)
          connection.extend(ActiveTableSet::Extensions::ConvenientDelegation)
        end

        connection
      end

      def pool_for_spec(spec)
        @connection_pools[spec] ||= ActiveRecord::ConnectionAdapters::ConnectionPool.new(spec)
      end

      def default_spec(spec)
        @class_to_pool["ActiveRecord::Base"] = pool_for_spec(spec)
      end

      def current_spec= (spec)
        pool_for_spec(spec)
        self.thread_connection_spec = spec
      end

      def current_config
        retrieve_connection_pool(ActiveRecord::Base).spec.config
      end

    end
  end
end
