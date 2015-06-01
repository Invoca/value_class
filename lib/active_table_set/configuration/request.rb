module ActiveTableSet
  module Configuration
    class Request
      include ValueClass::Constructable
      value_attr :table_set
      value_attr :access_mode
      value_attr :partition_key
      value_attr :timeout
      value_attr :test_scenario

      def merge(other_or_hash)
        other =
          if other_or_hash.is_a?(Hash)
            self.class.new(other_or_hash)
          else
            other_or_hash
          end

        # Do not use the current parition key if changing table sets.
        new_partition_key =
          if table_set == other.table_set
            other.partition_key || partition_key
          else
            other.partition_key
          end

        self.class.new(
          table_set:     other.table_set || table_set,
          access_mode:   other.access_mode || access_mode,
          partition_key: new_partition_key,
          timeout:       other.timeout || timeout,
          test_scenario: other.test_scenario || test_scenario
        )
      end
    end
  end
end
