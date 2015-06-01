# Adds convient access to the Acive Table Set methods.
module ActiveTableSet
  module Extensions
    module ConvenientDelegation
      def using(table_set: nil, access_mode: nil, partition_key: nil, timeout: nil, &blk)
        ActiveTableSet.using(table_set: table_set, access_mode: access_mode, partition_key: partition_key, timeout: timeout, &blk)
      end
    end
  end
end
