module ActiveTableSet
  module Configuration
    class DefaultConnection
      include ValueClass::Constructable
      value_attr :table_set,   required: true
      value_attr :access_mode, default: :write
      value_attr :partition_key
      value_attr :timeout
    end
  end
end
