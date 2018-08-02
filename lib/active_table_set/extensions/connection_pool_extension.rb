# frozen_string_literal: true

module ActiveTableSet
  module Extensions
    module ConnectionPoolExtension
      attr_reader :table_set

      def initialize(spec, table_set: nil)
        super(spec)

        @table_set = table_set ||  "_none_"
      end

      # ActiveTableSet allows just one timeout to be configured so the read_timeout will always be the same as write_timeout
      def table_set_with_timeout
        raw_read_timeout = spec.config["read_timeout"]
        read_timeout = raw_read_timeout.try(:to_i) || raw_read_timeout
        "#{@table_set}-#{read_timeout}"
      end
    end
  end
end
