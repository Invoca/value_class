require 'active_record'
require 'active_record/connection_adapters/mysql2_adapter'

require "active_table_set/version"
require 'active_table_set/table_set_config'
require 'active_table_set/database_config'
require 'active_table_set/partition_config'
require 'active_table_set/pool_manager'
require 'active_table_set/pool_key'
require 'active_table_set/partition'
require 'active_table_set/table_set'
require 'active_table_set/connection_proxy'
require 'active_table_set/connection_override'
require 'active_table_set/database_configuration_override'
require 'active_table_set/config_helpers'
require 'active_table_set/default_config_loader'
require 'active_table_set/query_parser'
require 'active_table_set/access_policy'
require 'yaml'
require 'active_support/core_ext'
require 'active_support/hash_with_indifferent_access'

module ActiveTableSet
end
