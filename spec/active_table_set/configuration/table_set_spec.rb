require 'spec_helper'

describe ActiveTableSet::Configuration::TableSet do
  let(:leader)         { { :host => "127.0.0.8",  :username => "tester",  :password => "verysecure",  :timeout => 2, :database => "main" } }
  let(:follower1)      { { :host => "127.0.0.9",  :username => "tester1", :password => "verysecure1", :timeout => 2, :database => "replication1" } }
  let(:follower2)      { { :host => "127.0.0.10", :username => "tester2", :password => "verysecure2", :timeout => 2, :database => "replication2" } }
  let(:partition_cfg)  { { :partition_key => 'alpha', :leader => leader, :followers => [follower1, follower2] } }
  let(:table_set_cfg)  { { :name => "test_ts", :partitions => [partition_cfg], :access_policy => { :disallow_read => "cf_%" } } }

  let(:beta_leader)    { { :host => "10.0.0.1",   :username => "beta",  :password => "verysecure",  :timeout => 2, :database => "main" } }
  let(:beta_follower1) { { :host => "10.0.0.2",   :username => "beta1", :password => "verysecure1", :timeout => 2, :database => "replication1" } }
  let(:beta_follower2) { { :host => "10.0.0.3",   :username => "beta2", :password => "verysecure2", :timeout => 2, :database => "replication2" } }
  let(:beta_partition_cfg) { { :partition_key => 'beta', :leader => beta_leader, :followers => [beta_follower1, beta_follower2] } }

  let(:multi_table_set_cfg)  { { :name => "test_multi", :partitions => [partition_cfg, beta_partition_cfg], :access_policy => { :disallow_read => "cf_%" } } }

  let(:config)        { ActiveTableSet::Configuration::TableSet.new(table_set_cfg) }

  context "config" do

    it "provides an array of Partition Configs" do
      expect(config.partitions.count).to eq(1)
    end

    it "support a dsl for defining the table set" do
      table_set = ActiveTableSet::Configuration::TableSet.config do |ts|
        ts.access_policy do |ap|
          ap.disallow_read = "cf_%"
        end

        ts.partition do |partition|
          partition.leader = leader
          partition.followers = [follower1, follower2]
        end
      end

      expect(table_set.access_policy.disallow_read).to eq("cf_%")
      expect(table_set.partitions.length).to eq(1)
      expect(table_set.partitions.first.leader.host).to eq("127.0.0.8")
    end
  end

  context "construction" do
    it "raises if not passed partitions" do
      expect { ActiveTableSet::Configuration::TableSet.new }.to raise_error(ArgumentError, "must provide one or more partitions")
    end

    it "can construct a table set with multiple partitions" do
      table_set = ActiveTableSet::Configuration::TableSet.new(multi_table_set_cfg)
      expect(table_set.partitions.count).to eq(2)
      expect(table_set.partitions.map(&:partition_key).sort).to eq(["alpha", "beta"])
    end

    it "raises an exception if we have more than one partition and any partitions do not have a key" do
      cfg = {
          partitions: [
              { :leader => leader, :followers => [follower1, follower2] },
              beta_partition_cfg
          ]
      }

      expect { ActiveTableSet::Configuration::TableSet.new(cfg) }.to raise_error(ArgumentError, "all partitions must have partition_keys if more than one partition is configured")
    end
  end

  context "partitioned?" do
    it "report false if only a single parititon provided" do
      config = ActiveTableSet::Configuration::TableSet.new(table_set_cfg)
      expect(config.partitioned?).to eq(false)
    end

    it "report true if multiple partitions" do
      config = ActiveTableSet::Configuration::TableSet.new(multi_table_set_cfg)
      expect(config.partitioned?).to eq(true)
    end
  end

  context "database_config" do
    it "when using a single partition, does not concern itself with the partition key" do
      table_set = ActiveTableSet::Configuration::TableSet.new(table_set_cfg)
      connection = table_set.database_config(access_mode: :write)
      expect(connection.host).to eq("127.0.0.8")
    end

    context "with multiple partitions" do
      it "returns connections out of the right partition when provided a key" do
        table_set = ActiveTableSet::Configuration::TableSet.new(multi_table_set_cfg)

        connection = table_set.database_config(access_mode: :write, partition_key: 'alpha')
        expect(connection.host).to eq("127.0.0.8")

        connection = table_set.database_config(access_mode: :write, partition_key: 'beta')
        expect(connection.host).to eq("10.0.0.1")
      end

      it "when using a multiple partitions, requires the partition key" do
        table_set = ActiveTableSet::Configuration::TableSet.new(multi_table_set_cfg)
        expect { table_set.database_config(access_mode: :write) }.to raise_error(ArgumentError, "Table set test_multi is partioned, you must provide a partition key. Available partitions: alpha, beta")
      end

      it "alerts when passing an invalid parition key" do
        table_set = ActiveTableSet::Configuration::TableSet.new(multi_table_set_cfg)
        expect { table_set.database_config(access_mode: :write, partition_key: 'omega') }.to raise_error(ArgumentError, "Partition omega not found in table set test_multi. Available partitions: alpha, beta")
      end
    end
  end
end
