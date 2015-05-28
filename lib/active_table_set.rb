require 'active_record'
require 'value_class'

require 'active_table_set/configuration/access_policy'
require 'active_table_set/configuration/default_connection'
require 'active_table_set/configuration/database_config'
require 'active_table_set/configuration/partition'
require 'active_table_set/configuration/table_set'
require 'active_table_set/configuration/config'

require 'active_table_set/extensions/connection_override'
require 'active_table_set/extensions/mysql_connection_monitor'

require 'active_table_set/version'
require 'active_table_set/pool_manager'
require 'active_table_set/connection_proxy'
require 'active_table_set/database_configuration_override'
require 'active_table_set/config_helpers'
require 'active_table_set/default_config_loader'
require 'active_table_set/query_parser'
require 'yaml'
require 'active_support/core_ext'
require 'active_support/hash_with_indifferent_access'

module ActiveTableSet
  class << self
    def config
      @config = ActiveTableSet::Configuration::Config.config { |conf| yield conf }
    end

    def enable
      @config or raise "You must specify a configuration before enabling ActiveTableSet"

      # Install extensions
      ActiveRecord::Base.send(:prepend, ActiveTableSet::Extensions::ConnectionOverride)

      @proxy = ActiveTableSet::ConnectionProxy.new(config: @config)
    end

    def connection_proxy
      @proxy
    end
  end
end
