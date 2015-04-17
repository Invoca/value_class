module ActiveTableSet
  class TableSetConfig
    attr_reader :writable_tables, :readable_tables, :partitions

    def initialize(config:)
      @partitions = config[:partitions].map { |part| ActiveTableSet::PartitionConfig.new(config: part) }
      @writable_tables = config[:writable]
      @readable_tables = config[:readable]
    end

    def partition_count
      @partitions.length
    end
  end
end
