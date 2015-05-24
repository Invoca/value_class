require 'spec_helper'

describe ActiveTableSet::Partition do
#  let(:config)    { ActiveTableSet::DatabaseConfig.new }
  let(:key)       { ActiveTableSet::PoolKey.new(host: "localhost", username: "tester", password: "verysecure", timeout: 5, config: config) }
  let(:db_config) { ActiveTableSet::DatabaseConfig.new(username: "tester", password: "verysecure", host: "localhost", timeout: 5)  }

  let(:leader)    { { :host => "127.0.0.8",  :username => "tester",  :password => "verysecure",  :timeout => 2, :database => "main" } }
  let(:follower1) { { :host => "127.0.0.9",  :username => "tester1", :password => "verysecure1", :timeout => 2, :database => "replication1" } }
  let(:follower2) { { :host => "127.0.0.10", :username => "tester2", :password => "verysecure2", :timeout => 2, :database => "replication2" } }
  let(:cfg)       { { :leader => leader, :followers => [follower1, follower2] } }

  let(:part)      { ActiveTableSet::Partition.new( leader: leader) }

  context "config" do
    it "provides a leader PoolKey" do
      config = ActiveTableSet::Partition.new(cfg)
      leader = config.leader_key

      expect(leader.host).to     eq("127.0.0.8")
      expect(leader.username).to eq("tester")
      expect(leader.password).to eq("verysecure")
      expect(leader.timeout).to  eq(2)
    end

    it "provides an array of followers PoolKeys" do
      config = ActiveTableSet::Partition.new(cfg)

      followers = config.follower_keys
      follower1 = followers.first
      follower2 = followers.last

      expect(follower1.host).to     eq("127.0.0.9")
      expect(follower1.username).to eq("tester1")
      expect(follower1.password).to eq("verysecure1")

      expect(follower2.host).to     eq("127.0.0.10")
      expect(follower2.username).to eq("tester2")
      expect(follower2.password).to eq("verysecure2")
    end
  end

  context "construction" do
    it "raises if not passed a leader" do
      expect { ActiveTableSet::Partition.new }.to raise_error(ArgumentError, "must provide a leader")
    end

    it "provides reasonable defaults" do
      expect(part.send(:keys).count).to eq(1)
      expect(part.index).to eq(0)
    end
  end

  context "connections" do
    let(:f1_key) { ActiveTableSet::PoolKey.new(host: "127.0.0.8", username: "tester", password: "verysecure", timeout: 5, config: db_config) }
    let(:f2_key) { ActiveTableSet::PoolKey.new(host: "127.0.0.9", username: "tester", password: "verysecure", timeout: 5, config: db_config) }

    it "provides a leader connection key for write access" do
      connection_key = part.connection_key(access_mode: :write)
      expect(connection_key).to eq(part.leader.pool_key)
    end

    it "provides a leader connection key for read access" do
      connection_key = part.connection_key(access_mode: :read)
      expect(connection_key).to eq(part.leader.pool_key)
    end

    it "provides a chosen follower connection key for balanced read access" do
      part2 = ActiveTableSet::Partition.new(cfg)
      expect(part2).to receive(:follower_index).and_return(0)
      connection_key = part2.connection_key(access_mode: :balanced)
      expect(connection_key).to eq(part2.followers.first.pool_key)
    end

    it "returns nil for balanced follower connection key if no followers" do
      connection_key = part.connection_key(access_mode: :balanced)
      expect(connection_key).to eq(nil)
    end

    it "raises if connection key requested with unknown access_mode" do
      expect { part.connection_key(access_mode: :something_weird) }.to raise_error(ArgumentError, "unknown access_mode")
    end
  end
end
