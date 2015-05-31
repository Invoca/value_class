require 'spec_helper'

describe ActiveTableSet::Configuration::TableSet do
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

  context "connection_spec" do
    it "when using a single partition, does not concern itself with the partition key" do
      table_set = small_table_set.table_sets.first
      request = ActiveTableSet::Configuration::Request.new(table_set: :foo, access_mode: :balanced, timeout: 100)

      con_spec = table_set.connection_spec(request, [], "foo")

      expect(con_spec.specification.host).to eq(table_set.partitions.first.leader.host)
      expect(con_spec.specification.username).to eq(table_set.partitions.first.leader.read_only_username)
    end

    it "passes along itself as an alternate database context, and forwards the access mode, access_policy and context" do
      table_set = small_table_set.table_sets.first
      request = ActiveTableSet::Configuration::Request.new(table_set: :foo, access_mode: :balanced, timeout: 120)

      con_spec = table_set.connection_spec(request, [], "foo")

      expect(con_spec.specification.database).to eq(table_set.database)
      expect(con_spec.access_policy).to eq(table_set.access_policy)
      expect(con_spec.connection_name).to eq("foo_common_balanced")
    end

    context "with multiple partitions" do
      it "returns connections out of the right partition when provided a key" do
        table_set = large_table_set.table_sets.last
        request = ActiveTableSet::Configuration::Request.new(table_set: :foo, access_mode: :write, timeout: 100, partition_key: "alpha")

        con_spec = table_set.connection_spec(request, [], "foo")

        expect(con_spec.specification.host).to     eq(table_set.partitions.first.leader.host)
        expect(con_spec.specification.username).to eq(table_set.partitions.first.leader.read_write_username)
      end

      it "when using a multiple partitions, requires the partition key" do
        table_set = large_table_set.table_sets.last
        request = ActiveTableSet::Configuration::Request.new(table_set: :foo, access_mode: :write, timeout: 100)
        expect { table_set.connection_spec(request, [], "foo") }.to raise_error(ArgumentError, "Table set sharded is partioned, you must provide a partition key. Available partitions: alpha, beta")
      end

      it "alerts when passing an invalid parition key" do
        table_set = large_table_set.table_sets.last
        request = ActiveTableSet::Configuration::Request.new(table_set: :foo, access_mode: :write, timeout: 100, partition_key: "omega")
        expect { table_set.connection_spec(request, [], "foo") }.to raise_error(ArgumentError, "Partition omega not found in table set sharded. Available partitions: alpha, beta")
      end
    end
  end
end
