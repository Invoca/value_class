require 'spec_helper'

describe ActiveTableSet::Partition do
  let(:mgr)       { ActiveTableSet::PoolManager.new }
  let(:config)    { ActiveTableSet::DatabaseConfig.new }
  let(:key)       { ActiveTableSet::PoolKey.new(host: "localhost", username: "tester", password: "verysecure", timeout: 5, config: config) }
  let(:part)      { ActiveTableSet::Partition.new(leader_key: key) }
  let(:db_config) { ActiveTableSet::DatabaseConfig.new(username: "tester", password: "verysecure", host: "localhost", timeout: 5)  }

  context "construction" do
    it "raises if not passed a leader" do
      expect { ActiveTableSet::Partition.new }.to raise_error(ArgumentError, "missing keyword: leader_key")
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
      expect(connection_key).to eq(key)
    end

    it "provides a leader connection key for read access" do
      connection_key = part.connection_key(access_mode: :read)
      expect(connection_key).to eq(key)
    end

    it "provides a chosen follower connection key for balanced read access" do
      part2 = ActiveTableSet::Partition.new(leader_key: key, follower_keys: [f1_key, f2_key])
      expect(part2).to receive(:follower_index).and_return(0)
      connection_key = part2.connection_key(access_mode: :balanced)
      expect(connection_key).to eq(f1_key)
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
