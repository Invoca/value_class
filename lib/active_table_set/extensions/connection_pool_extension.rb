# frozen_string_literal: true

module ActiveTableSet
  module Extensions
    module ConnectionPoolExtension
      attr_reader :table_set

      def initialize(spec, table_set: "_none_")
        super(spec)

        @table_set = table_set
      end
    end
  end
end
