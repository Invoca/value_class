require 'spec_helper'

module ActiveTableSet
  class << self
    def clear_for_testing
      @config = nil
      @proxy  = nil
    end
  end
end


describe ActiveTableSet do
  before :each do
    ActiveTableSet.clear_for_testing
  end

  it 'has a version number' do
    expect(ActiveTableSet::VERSION).not_to be nil
  end

  it "lets you specify a config" do
    ActiveTableSet.config do |conf|
      conf.enforce_access_policy true
      conf.environment           'test'
      conf.default_connection  =  { table_set: :common }

      conf.table_set do |ts|
        ts.name = :common

        ts.access_policy do |ap|
          ap.disallow_read  'cf_%'
          ap.disallow_write 'cf_%'
        end

        ts.partition do |part|
          part.leader do |leader|
            leader.host      "10.0.0.1"
            leader.username  "tester"
            leader.password  "verysecure"
            leader.timeout   2
            leader.database  "main"
          end
        end
      end
    end

    conf = ActiveTableSet.instance_variable_get('@config')
    expect(conf.table_sets.first.name).to eq(:common)
  end

  it "raises an exception if you enable before you config" do
    expect { ActiveTableSet.enable }.to raise_error(StandardError, "You must specify a configuration before enabling ActiveTableSet")
  end

  it "has an enable method that installs extensions and constructs the proxy" do
    ActiveTableSet.config do |conf|
      conf.enforce_access_policy true
      conf.environment           'test'
      conf.default_connection  =  { table_set: :common }

      conf.table_set do |ts|
        ts.name = :common

        ts.access_policy do |ap|
          ap.disallow_read  'cf_%'
          ap.disallow_write 'cf_%'
        end

        ts.partition do |part|
          part.leader do |leader|
            leader.host      "10.0.0.1"
            leader.username  "tester"
            leader.password  "verysecure"
            leader.timeout   2
            leader.database  "main"
          end
        end
      end
    end

    expect(ActiveRecord::Base).to receive(:prepend).with(ActiveTableSet::Extensions::ConnectionOverride)
    expect(Rails::Application::Configuration).to receive(:prepend).with(ActiveTableSet::Extensions::DatabaseConfigurationOverride)

    ActiveTableSet.enable

    proxy = ActiveTableSet.connection_proxy
    expect(proxy.class).to eq(ActiveTableSet::ConnectionProxy)
  end

  it "has a database_config method that delegates to the connection" do
    ActiveTableSet.config do |conf|
      conf.enforce_access_policy true
      conf.environment           'test'
      conf.default_connection  =  { table_set: :common }

      conf.table_set do |ts|
        ts.name = :common

        ts.access_policy do |ap|
          ap.disallow_read  'cf_%'
          ap.disallow_write 'cf_%'
        end

        ts.partition do |part|
          part.leader do |leader|
            leader.host      "10.0.0.1"
            leader.username  "tester"
            leader.password  "verysecure"
            leader.timeout   2
            leader.database  "main"
          end
        end
      end
    end

    config = ActiveTableSet.instance_eval('@config')
    expect(config).to receive(:database_configuration) { "configuration" }

    db_config = ActiveTableSet.database_configuration

    expect(db_config).to eq("configuration")
  end
end
