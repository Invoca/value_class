module ActiveTableSet
  class TableSetConfig
    attr_reader :writeable_tables, :readable_tables, :partitions

    def initialize(config:)
      @partitions = config[:partitions].map { |part| ActiveTableSet::PartitionConfig.new(config: part) }
      @writeable_tables = config[:writeable]
      @readable_tables = config[:readable]
    end

    def partition_count
      @partitions.length
    end
  end
end
