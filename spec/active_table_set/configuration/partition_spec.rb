# frozen_string_literal: true

require 'spec_helper'

describe ActiveTableSet::Configuration::Partition do
  let(:cfg)       { { leader: leader, followers: [follower1, follower2] } }
  let(:part)      { ActiveTableSet::Configuration::Partition.new(leader: leader) }

  context "config" do
    it "provides a leader" do
      config = ActiveTableSet::Configuration::Partition.new(cfg)
      leader = config.leader

      expect(leader.host).to     eq("127.0.0.8")
      expect(leader.read_write_username).to eq("tester")
      expect(leader.read_write_password).to eq("verysecure")
    end

    it "provides an array of followers" do
      config = ActiveTableSet::Configuration::Partition.new(cfg)

      followers = config.followers
      follower1 = followers.first
      follower2 = followers.last

      expect(follower1.host).to     eq("127.0.0.9")
      expect(follower1.read_write_username).to eq("tester1")
      expect(follower1.read_write_password).to eq("verysecure1")

      expect(follower2.host).to     eq("127.0.0.10")
      expect(follower2.read_write_username).to eq("tester2")
      expect(follower2.read_write_password).to eq("verysecure2")
    end

    it "can be progressively constructed" do
      config = ActiveTableSet::Configuration::Partition.config do |part|
        part.partition_key = 'alpha'
        part.database = 'greek_letters'

        part.leader do |leader|
          leader.host = "127.0.0.8"
          leader.read_write_username = "tester"
          leader.read_write_password = "verysecure"
          leader.database ="main"
        end

        part.follower do |follower|
          follower.host = "127.0.0.9"
          follower.read_write_username = "tester1"
          follower.read_write_password = "verysecure1"
          follower.database ="replication1"
        end

        part.follower do |follower|
          follower.host = "127.0.0.10"
          follower.read_write_username = "tester2"
          follower.read_write_password = "verysecure2"
          follower.database ="replication2"
        end
      end

      expect(config.partition_key).to eq("alpha")
      expect(config.database).to      eq("greek_letters")

      leader    = config.leader
      follower1 = config.followers.first
      follower2 = config.followers.last
      expect(leader.host).to     eq("127.0.0.8")
      expect(leader.read_write_username).to eq("tester")
      expect(leader.read_write_password).to eq("verysecure")

      expect(follower1.host).to     eq("127.0.0.9")
      expect(follower1.read_write_username).to eq("tester1")
      expect(follower1.read_write_password).to eq("verysecure1")

      expect(follower2.host).to     eq("127.0.0.10")
      expect(follower2.read_write_username).to eq("tester2")
      expect(follower2.read_write_password).to eq("verysecure2")
    end
  end

  context "construction" do
    it "raises if not passed a leader" do
      expect { ActiveTableSet::Configuration::Partition.new }.to raise_error(ArgumentError, "must provide a leader")
    end
  end

  context "connection_spec" do
    it "provides a connection to the leader using the read write user when in write mode" do
      part = large_table_set.table_sets.first.partitions.first
      request = ActiveTableSet::Configuration::Request.new(table_set: :foo, access: :leader, timeout: 100)

      con_attributes = part.connection_attributes(request, [], "foo", "access_policy")

      expect(con_attributes.pool_key.host).to eq(part.leader.host)
      expect(con_attributes.pool_key.username).to eq(part.leader.read_write_username)
    end

    it "passes through the timeout, access policy and connection_name" do
      part = large_table_set.table_sets.first.partitions.first
      request = ActiveTableSet::Configuration::Request.new(table_set: :foo, access: :leader, timeout: 100)

      con_attributes = part.connection_attributes(request, [], "foo", "access_policy")

      expect(con_attributes.access_policy).to eq("access_policy")
    end


    it "provides a follower connection key for read access" do
      part = large_table_set.table_sets.first.partitions.first
      request = ActiveTableSet::Configuration::Request.new(table_set: :foo, access: :follower, timeout: 100)

      con_attributes = part.connection_attributes(request, [], "foo", "access_policy")

      expect(con_attributes.pool_key.host).to eq(part.followers.first.host)
      expect(con_attributes.pool_key.username).to eq(part.followers.first.read_only_username)
      expect(con_attributes.failover_pool_key).to eq(nil)
    end

    it "uses leader as follower if there are no followers" do
      part = small_table_set.table_sets.first.partitions.first
      request = ActiveTableSet::Configuration::Request.new(table_set: :foo, access: :follower, timeout: 100)

      con_attributes = part.connection_attributes(request, [small_table_set.table_sets.first], "foo", "access_policy")

      expect(con_attributes.pool_key.host).to eq(part.leader.host)
      expect(con_attributes.pool_key.username).to eq(part.leader.read_only_username)
    end

    it "provides a chosen database config for balanced read access (when leader is chosen)" do
      allow(ActiveTableSet::Configuration::Partition).to receive(:pid).and_return(0)

      part = large_table_set.table_sets.first.partitions.first
      request = ActiveTableSet::Configuration::Request.new(table_set: :foo, access: :balanced, timeout: 100)

      con_attributes = part.connection_attributes(request, [], "foo", "access_policy")

      expect(con_attributes.pool_key.host).to eq(part.leader.host)
      expect(con_attributes.pool_key.username).to eq(part.leader.read_only_username)
      expect(con_attributes.failover_pool_key).to eq(nil)
    end

    it "provides a chosen database config for balanced read access (when follower is chosen)" do
      allow(ActiveTableSet::Configuration::Partition).to receive(:pid).and_return(1)

      part = large_table_set.table_sets.first.partitions.first
      request = ActiveTableSet::Configuration::Request.new(table_set: :foo, access: :balanced, timeout: 100)

      con_attributes = part.connection_attributes(request, [], "foo", "access_policy")

      expect(con_attributes.pool_key.host).to eq(part.followers.first.host)
      expect(con_attributes.pool_key.username).to eq(part.followers.first.read_only_username)

      # When follower is chosen, fail back to leader host.
      expect(con_attributes.failover_pool_key.host).to eq(part.leader.host)
    end

    it "provides a chosen database config for balanced access (when no followers)" do
      allow(ActiveTableSet::Configuration::Partition).to receive(:pid).and_return(1)

      part = large_table_set.table_sets.first.partitions.first.clone_config { |clone| clone.followers = [] }
      request = ActiveTableSet::Configuration::Request.new(table_set: :foo, access: :balanced, timeout: 100)

      con_attributes = part.connection_attributes(request, [], "foo", "access_policy")

      expect(con_attributes.pool_key.host).to eq(part.leader.host)
      expect(con_attributes.pool_key.username).to eq(part.leader.read_only_username)
    end
  end
end
