# frozen_string_literal: true

module ActiveTableSet
  module Configuration
    class Request
      include ValueClass::Constructable
      value_attr :table_set
      value_attr :access, limit: [:leader, :follower, :balanced]
      value_attr :partition_key
      value_attr :timeout
      value_attr :net_read_timeout
      value_attr :net_write_timeout
      value_attr :test_scenario

      def access
        access_override_from_process_settings || @access
      end

      def merge(other_or_hash)
        other = other_or_hash.is_a?(Hash) ? self.class.new(other_or_hash) : other_or_hash

        # Do not use the current parition key if changing table sets.
        self.class.new(
          to_hash
            .merge(other.to_hash.compact)
            .merge(partition_key: new_partition_key(other))
            .compact
            .symbolize_keys
        )
      end

      def cache_key
        [
          table_set,
          access,
          partition_key,
          timeout,
          net_read_timeout,
          net_write_timeout,
          test_scenario
        ].freeze
      end

      private

      def new_partition_key(other)
        if other.table_set
          if table_set == other.table_set
            other.partition_key || partition_key
          else
            other.partition_key
          end
        else
          partition_key
        end
      end

      def access_override_from_process_settings
        scoped_setting_key = [table_set, partition_key].compact.join('-')
        ProcessSettings['active_table_set', scoped_setting_key, 'access_override', required: false]&.to_sym
      end
    end
  end
end
