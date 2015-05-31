# TODO - Request or ConfigurationRequest
#
# This is basically the user requested table set configuration.
module ActiveTableSet
  module Configuration
    class Request
      include ValueClass::Constructable
      value_attr :table_set,   required: true
      value_attr :access_mode, default: :write
      value_attr :partition_key
      value_attr :timeout
      value_attr :test_scenario
    end
  end
end
