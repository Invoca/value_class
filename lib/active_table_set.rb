require 'active_record'
require 'value_class'

require 'active_table_set/configuration/database_connection'
require 'active_table_set/configuration/access_policy'
require 'active_table_set/configuration/using_spec'
require 'active_table_set/configuration/test_scenario'
require 'active_table_set/configuration/partition'
require 'active_table_set/configuration/table_set'
require 'active_table_set/configuration/config'

require 'active_table_set/extensions/connection_override'
require 'active_table_set/extensions/database_configuration_override'
require 'active_table_set/extensions/mysql_connection_monitor'

require 'active_table_set/version'
require 'active_table_set/pool_manager'
require 'active_table_set/connection_proxy'
require 'active_table_set/query_parser'
require 'active_support/core_ext'
require 'active_support/hash_with_indifferent_access'
require 'rails'

module ActiveTableSet
  # The user settings mapped to internal structures...
  # TODO - Does this need a connection name?
  # TODO - these names are WAY too close
  ConnectionSpec = ValueClass.struct(:specification, :access_policy, :timeout, :connection_name)

  # The specification passed to the database layer
  ConnectionSpecification = ValueClass.struct(:host, :database, :username, :password, :connect_timeout, :read_timeout, :write_timeout, :encoding, :collation, :adapter, :pool, :reconnect)

  class << self
    def config
      @config = ActiveTableSet::Configuration::Config.config { |conf| yield conf }
    end

    def enable
      @config or raise "You must specify a configuration before enabling ActiveTableSet"

      # Install extensions
      ActiveRecord::Base.send(:prepend, ActiveTableSet::Extensions::ConnectionOverride)
      Rails::Application::Configuration.send(:prepend, ActiveTableSet::Extensions::DatabaseConfigurationOverride)

      @proxy = ActiveTableSet::ConnectionProxy.new(config: @config)
    end

    def connection_proxy
      @proxy
    end

    def database_configuration
      @config or raise "You must specify a configuration before calling database_configuration"
      @config.database_configuration
    end
  end
end
