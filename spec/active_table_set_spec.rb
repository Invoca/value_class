require 'spec_helper'

module ActiveTableSet
  class << self
    def clear_for_testing
      @config = nil
      @manager  = nil
    end

    def add_stub_manager(stub)
      @manager = stub
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
      conf.default  =  { table_set: :common }

      conf.table_set do |ts|
        ts.name = :common

        ts.access_policy do |ap|
          ap.disallow_read  'cf_%'
          ap.disallow_write 'cf_%'
        end

        ts.partition do |part|
          part.leader do |leader|
            leader.host                 "10.0.0.1"
            leader.read_write_username  "tester"
            leader.read_write_password  "verysecure"
            leader.database             "main"
          end
        end
      end
    end

    conf = ActiveTableSet.instance_variable_get('@config')
    expect(conf.table_sets.first.name).to eq(:common)
  end

  it "raises an exception if you enable before you config" do
    expect { ActiveTableSet.enable }.to raise_error(StandardError, "You must specify a configuration")
  end

  it "has an enable method that installs extensions and constructs the manager" do
    ActiveTableSet.config do |conf|
      conf.enforce_access_policy true
      conf.environment           'test'
      conf.default  =  { table_set: :common }

      conf.table_set do |ts|
        ts.name = :common

        ts.access_policy do |ap|
          ap.disallow_read  'cf_%'
          ap.disallow_write 'cf_%'
        end

        ts.partition do |part|
          part.leader do |leader|
            leader.host                 "10.0.0.1"
            leader.read_write_username  "tester"
            leader.read_write_password  "verysecure"
            leader.database             "main"
          end
        end
      end
    end

    expect(ActiveRecord::ConnectionAdapters::ConnectionHandler).to receive(:prepend).with(ActiveTableSet::Extensions::ConnectionHandlerExtension)
    expect(Rails::Application::Configuration).to receive(:prepend).with(ActiveTableSet::Extensions::DatabaseConfigurationOverride)

    expect(ActiveRecord::TestFixtures).to receive(:prepend).with(ActiveRecord::TestFixturesExtension)

    expect(ActiveRecord::Base.connection_handler).to receive(:default_spec)

    ActiveTableSet.enable

    manager = ActiveTableSet.instance_eval('@manager')

    expect(manager.class).to eq(ActiveTableSet::ConnectionManager)

    expect(ActiveTableSet.enforce_access_policy?).to eq(true)
  end

  it "has a database_config method that delegates to the connection" do
    ActiveTableSet.config do |conf|
      conf.enforce_access_policy true
      conf.environment           'test'
      conf.default  =  { table_set: :common }

      conf.table_set do |ts|
        ts.name = :common

        ts.access_policy do |ap|
          ap.disallow_read  'cf_%'
          ap.disallow_write 'cf_%'
        end

        ts.partition do |part|
          part.leader do |leader|
            leader.host                 "10.0.0.1"
            leader.read_write_username  "tester"
            leader.read_write_password  "verysecure"
            leader.database             "main"
          end
        end
      end
    end

    config = ActiveTableSet.instance_eval('@config')
    expect(config).to receive(:database_configuration) { "configuration" }

    db_config = ActiveTableSet.database_configuration

    expect(db_config).to eq("configuration")
  end

  context "using" do
    it "raises if not configured" do
      expect { ActiveTableSet.using {} }.to raise_error(StandardError, "You must call enable first")
    end

    it "delegates the using method" do
      mgr_dbl = double("stub_proxy")

      @called_block = false

      ActiveTableSet.add_stub_manager(mgr_dbl)
      expect(mgr_dbl).to receive(:using).with(table_set: :ts, access: :am, partition_key: :pk, timeout: :t).and_yield
      ActiveTableSet.using(table_set: :ts, access: :am, partition_key: :pk, timeout: :t) do
        @called_block = true
      end

      expect(@called_block).to eq(true)
    end
  end

  context "use_test_scenario" do
    it "raises if not configured" do
      expect { ActiveTableSet.use_test_scenario(:foo) }.to raise_error(StandardError, "You must call enable first")
    end

    it "delegates the using method" do
      mgr_dbl = double("stub_proxy")

      @called_block = false

      ActiveTableSet.add_stub_manager(mgr_dbl)
      expect(mgr_dbl).to receive(:use_test_scenario).with(:foo)
      ActiveTableSet.use_test_scenario(:foo)
    end
  end

  context "lock_access" do
    it "raises if not configured" do
      expect { ActiveTableSet.lock_access(:foo) }.to raise_error(StandardError, "You must call enable first")
    end

    it "delegates the using method" do
      mgr_dbl = double("stub_proxy")

      @called_block = false

      ActiveTableSet.add_stub_manager(mgr_dbl)
      expect(mgr_dbl).to receive(:lock_access).with(:foo)
      ActiveTableSet.lock_access(:foo)
    end
  end

  context "access_policy" do
    it "raises if not configured" do
      expect { ActiveTableSet.access_policy }.to raise_error(StandardError, "You must call enable first")
    end

    it "delegates" do
      mgr_dbl = double("stub_proxy")
      ActiveTableSet.add_stub_manager(mgr_dbl)
      expect(mgr_dbl).to receive(:access_policy)
      ActiveTableSet.access_policy
    end

    it "allows test methods access" do
      mgr_dbl = double("stub_proxy")

      @called_block = false

      ActiveTableSet.add_stub_manager(mgr_dbl)
      expect(mgr_dbl).to receive(:allow_test_access).and_yield
      ActiveTableSet.allow_test_access do
        @called_block = true
      end

      expect(@called_block).to eq(true)
    end
  end

  it "reports not configured " do
    expect(ActiveTableSet.configured?).to eq(false)

    ActiveTableSet.config do |conf|
      conf.enforce_access_policy true
      conf.environment           'test'
      conf.default  =  { table_set: :common }

      conf.table_set do |ts|
        ts.name = :common

        ts.access_policy do |ap|
          ap.disallow_read  'cf_%'
          ap.disallow_write 'cf_%'
        end

        ts.partition do |part|
          part.leader do |leader|
            leader.host                 "10.0.0.1"
            leader.read_write_username  "tester"
            leader.read_write_password  "verysecure"
            leader.database             "main"
          end
        end
      end
    end

    expect(ActiveTableSet.configured?).to eq(true)
  end

end
