require 'active_record'
require 'value_class'

#???
require 'active_record/connection_adapters/mysql2_adapter'

require 'active_table_set/configuration/access_policy'
require 'active_table_set/configuration/default_connection'
require 'active_table_set/configuration/database_config'
require 'active_table_set/configuration/partition'
require 'active_table_set/configuration/table_set'
require 'active_table_set/configuration/config'

require 'active_table_set/version'
require 'active_table_set/pool_manager'
require 'active_table_set/connection_proxy'
require 'active_table_set/connection_override'
require 'active_table_set/database_configuration_override'
require 'active_table_set/config_helpers'
require 'active_table_set/default_config_loader'
require 'active_table_set/query_parser'
require 'active_table_set/mysql_connection_monitor'
require 'yaml'
require 'active_support/core_ext'
require 'active_support/hash_with_indifferent_access'

module ActiveTableSet
end
