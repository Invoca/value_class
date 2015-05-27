require 'spec_helper'

describe ActiveTableSet::Configuration::Config do
  let(:leader)         { { :host => "127.0.0.8",  :username => "tester",  :password => "verysecure",  :timeout => 2, :database => "main" } }
  let(:follower1)      { { :host => "127.0.0.9",  :username => "tester1", :password => "verysecure1", :timeout => 2, :database => "replication1" } }
  let(:follower2)      { { :host => "127.0.0.10", :username => "tester2", :password => "verysecure2", :timeout => 2, :database => "replication2" } }
  let(:partition_cfg)  { { :partition_key => 'alpha', :leader => leader, :followers => [follower1, follower2] } }
  let(:table_set_cfg)  { { :name => "test_ts", :partitions => [partition_cfg], :access_policy => { :disallow_read => "cf_%" } } }

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

  it "raises if no table set was specified" do
    expect { ActiveTableSet::Configuration::Config.new(default_connection:{table_set: :common}) }.to raise_error(ArgumentError, "no table sets defined")
  end

  it "raises if a default connection setting is not specified" do
    expect { ActiveTableSet::Configuration::Config.new(table_sets: [table_set_cfg]) }.to raise_error(ArgumentError, "must provide a value for default_connection")
  end
end
