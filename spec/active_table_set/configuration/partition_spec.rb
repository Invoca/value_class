require 'spec_helper'

describe ActiveTableSet::Configuration::Partition do
  let(:cfg)       { { :leader => leader, :followers => [follower1, follower2] } }
  let(:part)      { ActiveTableSet::Configuration::Partition.new( leader: leader) }

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
      request = ActiveTableSet::Configuration::Request.new(table_set: :foo, access_mode: :write, timeout: 100)

      con_spec = part.connection_spec(request, [], "foo", "access_policy")

      expect(con_spec.pool_key.host).to eq(part.leader.host)
      expect(con_spec.pool_key.username).to eq(part.leader.read_write_username)
    end

    it "passes through the timeout, access policy and connection_name" do
      part = large_table_set.table_sets.first.partitions.first
      request = ActiveTableSet::Configuration::Request.new(table_set: :foo, access_mode: :write, timeout: 100)

      con_spec = part.connection_spec(request, [], "foo", "access_policy")

      expect(con_spec.access_policy).to eq("access_policy")
      expect(con_spec.connection_name).to eq("foo_write")
    end


    # TODO - this is wrong.  Read access should prefer to avoid the leader.
    it "provides a leader connection key for read access" do
      part = large_table_set.table_sets.first.partitions.first
      request = ActiveTableSet::Configuration::Request.new(table_set: :foo, access_mode: :read, timeout: 100)

      con_spec = part.connection_spec(request, [], "foo", "access_policy")

      expect(con_spec.pool_key.host).to eq(part.leader.host)
      expect(con_spec.pool_key.username).to eq(part.leader.read_only_username)
    end

    it "provides a chosen database config for balanced read access (when leader is chosen)" do
      allow(ActiveTableSet::Configuration::Partition).to receive(:pid).and_return(0)

      part = large_table_set.table_sets.first.partitions.first
      request = ActiveTableSet::Configuration::Request.new(table_set: :foo, access_mode: :balanced, timeout: 100)

      con_spec = part.connection_spec(request, [], "foo", "access_policy")

      expect(con_spec.pool_key.host).to eq(part.leader.host)
      expect(con_spec.pool_key.username).to eq(part.leader.read_only_username)
    end

    it "provides a chosen database config for balanced read access (when follower is chosen)" do
      allow(ActiveTableSet::Configuration::Partition).to receive(:pid).and_return(1)

      part = large_table_set.table_sets.first.partitions.first
      request = ActiveTableSet::Configuration::Request.new(table_set: :foo, access_mode: :balanced, timeout: 100)

      con_spec = part.connection_spec(request, [], "foo", "access_policy")

      expect(con_spec.pool_key.host).to eq(part.followers.first.host)
      expect(con_spec.pool_key.username).to eq(part.followers.first.read_only_username)
    end

    it "provides a chosen database config for balanced access (when no followers)" do
      allow(ActiveTableSet::Configuration::Partition).to receive(:pid).and_return(1)

      part = large_table_set.table_sets.first.partitions.first.clone_config { |clone| clone.followers = [] }
      request = ActiveTableSet::Configuration::Request.new(table_set: :foo, access_mode: :balanced, timeout: 100)

      con_spec = part.connection_spec(request, [], "foo", "access_policy")

      expect(con_spec.pool_key.host).to eq(part.leader.host)
      expect(con_spec.pool_key.username).to eq(part.leader.read_only_username)
    end

    it "raises if connection key requested with unknown access_mode" do
      part = large_table_set.table_sets.first.partitions.first
      request = ActiveTableSet::Configuration::Request.new(table_set: :foo, access_mode: :something_weird, timeout: 100)

      expect { part.connection_spec(request, [], "foo", "access_policy") }.to raise_error(ArgumentError, "unknown access_mode something_weird")
    end
  end
end
