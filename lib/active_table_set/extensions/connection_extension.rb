# frozen_string_literal: true

# Adds extra logging detail.
module ActiveTableSet
  module Extensions
    module ConnectionExtension
      def log(sql, name='', builds=[])
        super(sql, "#{name} host:#{@config[:host]}", builds)
      end
    end
  end
end
