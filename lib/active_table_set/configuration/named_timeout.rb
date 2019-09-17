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
        {
          timeout:           timeout,
          net_read_timeout:  net_read_timeout,
          net_write_timeout: net_write_timeout
        }
      end
    end
  end
end
