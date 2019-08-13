# frozen_string_literal: true

module ActiveTableSet
  module Configuration
    class NamedTimeout
      include ValueClass::Constructable

      value_attr :name,    required: true
      value_attr :timeout, required: true
      value_attr :net_read_timeout
    end
  end
end
