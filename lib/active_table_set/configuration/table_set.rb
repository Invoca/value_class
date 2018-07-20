module ActiveTableSet
  module Configuration
    class TableSet < DatabaseConnection
      value_attr      :name
      value_attr      :access_policy,  class_name: 'ActiveTableSet::Configuration::AccessPolicy', default: {}
      value_list_attr :partitions,     class_name: 'ActiveTableSet::Configuration::Partition', insert_method: :partition
      value_attr      :before_enable

      def initialize(options = {})
        super

        partitions.any? or raise ArgumentError, "must provide one or more partitions"

        if partitioned?
          partitions.all?(&:partition_key) or raise ArgumentError, "all partitions must have partition_keys if more than one partition is configured"
          @partitions_by_key = partitions.inject({}) { |memo, part| memo[part.partition_key] = part; memo }
        end
      end

      def partitioned?
        partitions.count > 1
      end

      def connection_attributes(request, database_connections, connection_name_prefix)
        updated_prefix = "#{connection_name_prefix}_#{name}"
        target_partition =
          if partitioned?
            partition_key = request.partition_key
            partition_key or raise ArgumentError, "Table set #{name} is partioned, you must provide a partition key. Available partitions: #{partition_keys.join(', ')}"

            (selected_partition = @partitions_by_key[partition_key]) or raise ArgumentError, "Partition #{partition_key} not found in table set #{name}. Available partitions: #{partition_keys.join(', ')}"

            selected_partition
          else
            partitions.first
          end

        target_partition.connection_attributes(request, [self] + database_connections, updated_prefix, access_policy)
      end

      private

      def partition_keys
        @partitions.map(&:partition_key)
      end
    end
  end
end
