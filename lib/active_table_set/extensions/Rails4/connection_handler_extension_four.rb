module ActiveTableSet
  module Extensions
    module ConnectionHandlerExtensionFour
      def self.prepended(klass)
        klass.send(:include, ValueClass::ThreadLocalAttribute)
        klass.thread_local_instance_attr :thread_connection_spec
      end

      # Overwrites the connection handler method.
      # Prefers the pool for the current spec, if any.
      def retrieve_connection_pool(klass)
        (thread_connection_spec && pool_for_spec(thread_connection_spec)) || super
      end

      # Disables the remove connection method on default
      def remove_connection(klass)
        if klass.name != 'ActiveRecord::Base'
          super
        end
      end

      # Overwrites the connection handler method.
      # Extends the connection class if needed.
      def retrieve_connection(klass)
        connection = super

        unless connection.respond_to?(:using)
          connection.class.send(:include, ActiveTableSet::Extensions::ConnectionExtension)
        end

        if ActiveTableSet.enforce_access_policy? && !connection.respond_to?(:show_error_in_bars)
          connection.extend(ActiveTableSet::Extensions::MysqlConnectionMonitor)
        end

        connection
      end

      # Overwrites the connection handler method so that the pool specification is normalized
      def establish_connection(name, spec)
        @class_to_pool[name] = pool_for_spec(spec)
      end

      def default_spec(spec)
        @class_to_pool["ActiveRecord::Base"] = pool_for_spec(spec)
      end

      def current_spec= (spec)
        pool_for_spec(spec)
        self.thread_connection_spec = spec
      end

      def pool_for_spec(spec)
        normalized_config = spec.config.dup.stringify_keys # These are sometimes strings and sometimes symbols.
        normalized_config.delete("flags")                  # The mysql2 adapter mutates the config to add this flag, which causes mayhem.
        binding.pry
        @connection_pools[normalized_config] ||= ActiveRecord::ConnectionAdapters::ConnectionPool.new(spec.dup)
      end
    end
  end
end
