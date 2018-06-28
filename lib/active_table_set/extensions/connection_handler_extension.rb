module ActiveTableSet
  module Extensions
    module ConnectionHandlerExtension
      def self.prepended(klass)
        klass.send(:include, ValueClass::ThreadLocalAttribute)
        klass.thread_local_instance_attr :thread_connection_spec  # holds the `using` preference per thread/fiber
      end

      attr_accessor :test_scenario_connection_spec                # holds the `use_test_scenario` spec globally (across all threads/fibers)

      # Overwrites connection handler method - retrieves
      # the current
      def establish_connection(owner, spec)
        @class_to_pool.clear
        owner.name or raise RuntimeError, "Anonymous class is not allowed."
        owner_to_pool[owner.name] = pool_for_spec(spec)
      end

      # Overrides the connection handler method.
      # Prefers the pool for the current spec, if any.
      def retrieve_connection_pool(klass)
        if (current_connection_spec = thread_connection_spec || test_scenario_connection_spec)
          pool_for_spec(current_connection_spec)
        else
          super
        end
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

      def normalize_config(config)
        normalized_config = config.symbolize_keys     # These are sometimes strings and sometimes symbols.
        normalized_config.delete(:flags)              # The mysql2 adapter mutates the config to add this flag, which causes mayhem.
        normalized_config
      end

      def default_spec(spec)
        establish_connection(ActiveRecord::Base, spec)
      end

      def current_spec= (spec)
        pool_for_spec(spec)
        self.thread_connection_spec = spec
      end


      def connection_pools
        @connection_pools ||= {}
      end

      def pool_for_spec(spec)
        connection_pools[normalize_config(spec.config)] ||=
            if spec.config[:adapter] == "fibered_mysql2"
              require 'active_table_set/fibered_database_connection_pool'
              require 'active_table_set/extensions/fibered_mysql2_connection_factory'
              ActiveRecord::Base.class.prepend(ActiveTableSet::Extensions::FiberedMysql2ConnectionFactory)

              FiberedDatabaseConnectionPool.new(spec.dup)
            else
              ActiveRecord::ConnectionAdapters::ConnectionPool.new(spec.dup)
            end
      end
    end
  end
end
