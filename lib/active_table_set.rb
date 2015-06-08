# -*- coding: utf-8 -*-

require 'active_record'
require 'value_class'

require 'active_table_set/pool_key'
require 'active_table_set/connection_attributes'

require 'active_table_set/configuration/named_timeout'
require 'active_table_set/configuration/database_connection'
require 'active_table_set/configuration/access_policy'
require 'active_table_set/configuration/request'
require 'active_table_set/configuration/test_scenario'
require 'active_table_set/configuration/partition'
require 'active_table_set/configuration/table_set'
require 'active_table_set/configuration/config'

require 'active_table_set/extensions/connection_override'
require 'active_table_set/extensions/database_configuration_override'
require 'active_table_set/extensions/mysql_connection_monitor'
require 'active_table_set/extensions/convenient_delegation'
require 'active_table_set/extensions/fixture_test_scenarios'

require 'active_table_set/version'
require 'active_table_set/pool_manager'
require 'active_table_set/connection_manager'
require 'active_table_set/query_parser'
require 'active_support/core_ext'
require 'active_support/hash_with_indifferent_access'
require 'rails'

module ActiveTableSet
  class << self
    def config(&blk)
      @config = ActiveTableSet::Configuration::Config.config(&blk)
    end

    def enable
      configuration

      # Install extensions
      ActiveRecord::Base.singleton_class.send(:prepend, ActiveTableSet::Extensions::ConnectionOverride)
      Rails::Application::Configuration.send(:prepend, ActiveTableSet::Extensions::DatabaseConfigurationOverride)
      ActiveRecord::TestFixtures.send(:prepend, ActiveRecord::TestFixturesExtension)

      @manager = ActiveTableSet::ConnectionManager.new(config: configuration, pool_manager: ActiveTableSet::PoolManager.new)
    end

    def connection
      manager.connection
    end

    def using(table_set: nil, access: nil, partition_key: nil, timeout: nil, &blk)
      manager.using(table_set: table_set, access: access, partition_key: partition_key, timeout: timeout, &blk)
    end

    def use_test_scenario(test_scenario)
      manager.use_test_scenario(test_scenario)
    end

    def lock_access(access, &blk)
      manager.lock_access(access, &blk)
    end

    def database_configuration
      configuration.database_configuration
    end

    def manager
      @manager or raise "You must call enable first"
    end

    def configuration
      @config or raise "You must specify a configuration"
    end

  end
end
