require 'spec_helper'

describe ActiveTableSet::Configuration::Config do
  let(:leader)         { { :host => "127.0.0.8",  :username => "tester",  :password => "verysecure",  :timeout => 2, :database => "main" } }
  let(:follower1)      { { :host => "127.0.0.9",  :username => "tester1", :password => "verysecure1", :timeout => 2, :database => "replication1" } }
  let(:follower2)      { { :host => "127.0.0.10", :username => "tester2", :password => "verysecure2", :timeout => 2, :database => "replication2" } }
  let(:partition_cfg)  { { :partition_key => 'alpha', :leader => leader, :followers => [follower1, follower2] } }
  let(:table_set_cfg)  { { :name => "test_ts", :partitions => [partition_cfg], :access_policy => { :disallow_read => "cf_%" } } }

  let(:large_table_set) do
    ats_config = ActiveTableSet::Configuration::Config.config do |conf|
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

          part.follower do |follower|
            follower.host      "10.0.0.2"
            follower.username  "tester1"
            follower.password  "verysecure1"
            follower.timeout   2
            follower.database  "replication1"
          end

          part.follower do |follower|
            follower.host      "10.0.0.3"
            follower.username  "tester2"
            follower.password  "verysecure2"
            follower.timeout   2
            follower.database  "replication2"
          end
        end
      end

      conf.table_set do |ts|
        ts.name = :sharded

        ts.access_policy do |ap|
          ap.allow_write    'cf_%'
        end

        ts.partition do |part|
          part.partition_key 'alpha'
          part.leader do |leader|
            leader.host      "11.0.1.1"
            leader.username  "tester"
            leader.password  "verysecure"
            leader.timeout   2
            leader.database  "main"
          end

          part.follower do |follower|
            follower.host      "11.0.1.2"
            follower.username  "tester1"
            follower.password  "verysecure1"
            follower.timeout   2
            follower.database  "replication1"
          end

          part.follower do |follower|
            follower.host      "11.0.1.3"
            follower.username  "tester2"
            follower.password  "verysecure2"
            follower.timeout   2
            follower.database  "replication2"
          end
        end

        ts.partition do |part|
          part.partition_key 'beta'

          part.leader do |leader|
            leader.host      "11.0.2.1"
            leader.username  "tester"
            leader.password  "verysecure"
            leader.timeout   2
            leader.database  "main"
          end

          part.follower do |follower|
            follower.host      "11.0.2.2"
            follower.username  "tester1"
            follower.password  "verysecure1"
            follower.timeout   2
            follower.database  "replication1"
          end

          part.follower do |follower|
            follower.host      "11.0.2.3"
            follower.username  "tester2"
            follower.password  "verysecure2"
            follower.timeout   2
            follower.database  "replication2"
          end
        end
      end
    end
  end

  it "can be constructed using a block" do
    ats_config = ActiveTableSet::Configuration::Config.config do |conf|
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
            leader.host      "127.0.0.8"
            leader.username  "tester"
            leader.password  "verysecure"
            leader.timeout   2
            leader.database  "main"
          end

          part.follower do |follower|
            follower.host      "127.0.0.9"
            follower.username  "tester1"
            follower.password  "verysecure1"
            follower.timeout   2
            follower.database  "replication1"
          end

          part.follower do |follower|
            follower.host      "127.0.0.10"
            follower.username  "tester2"
            follower.password  "verysecure2"
            follower.timeout   2
            follower.database  "replication2"
          end
        end
      end
    end

    expect(ats_config.table_sets.size).to eq(1)
    expect(ats_config.enforce_access_policy).to eq(true)
  end

  it "allows test scenarios to be specified" do
    ats_config = ActiveTableSet::Configuration::Config.config do |conf|
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
            leader.host      "127.0.0.8"
            leader.username  "tester"
            leader.password  "verysecure"
            leader.timeout   2
            leader.database  "main"
          end
        end
      end

      conf.test_scenario do |ts|
        ts.scenario_name "legacy"
        ts.host      "127.0.0.8"
        ts.username  "tester"
        ts.password  "verysecure"
        ts.timeout   2
        ts.database  "main"
      end

      conf.test_scenario do |ts|
        ts.scenario_name "adwords"
        ts.host      "127.0.0.8"
        ts.username  "tester"
        ts.password  "verysecure"
        ts.timeout   2
        ts.database  "main"
      end
    end

    expect(ats_config.test_scenarios.size).to eq(2)
    expect(ats_config.test_scenarios.first.scenario_name).to eq("legacy")
  end

  it "raises if no table set was specified" do
    expect { ActiveTableSet::Configuration::Config.new(default_connection:{table_set: :common}) }.to raise_error(ArgumentError, "no table sets defined")
  end

  it "raises if a default connection setting is not specified" do
    expect { ActiveTableSet::Configuration::Config.new(table_sets: [table_set_cfg]) }.to raise_error(ArgumentError, "must provide a value for default_connection")
  end

  context "database_config" do
    it "finds common connections" do
      db_config = large_table_set.database_config(table_set: :common)

      expect(db_config.host).to eq("10.0.0.1")
    end

    it "finds sharded connections" do
      db_config = large_table_set.database_config(table_set: :sharded, partition_key: "alpha")

      expect(db_config.host).to eq("11.0.1.1")
    end

    it "raises if the table set is not found" do
      expect { large_table_set.database_config(table_set: :not_found) }.to raise_error(ArgumentError, "Unknown table set not_found, available_table_sets: common, sharded")
    end
  end
end
