# frozen_string_literal: true

module ActiveTableSet
  module Configuration
    class NamedTimeout
      include ValueClass::Constructable

      value_attr :name,    required: true
      value_attr :timeout, required: true
      value_attr :net_read_timeout
      value_attr :net_write_timeout

      def timeout_hash
        to_hash.symbolize_keys.except(:name)
      end
    end
  end
end
