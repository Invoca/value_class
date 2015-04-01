require 'spec_helper'

describe ActiveTableSet::Partition do
  let(:mgr) { ActiveTableSet::PoolManager.new }
  let(:key) { ActiveTableSet::PoolKey.new(host: "localhost", username: "tester", password: "verysecure", timeout: 5) }
  let(:part){ ActiveTableSet::Partition.new(leader_key: key) }

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
    it "provides a leader connection key" do
      leader = part.send(:leader)
      allow(leader).to receive(:connection_key) { key }
      connection_key = part.connection_key(mode: :leader)
      expect(connection_key).to eq(key)
    end

    it "returns nil for balanced follower connection key if no followers" do
      connection_key = part.connection_key(mode: :balanced)
      expect(connection_key).to eq(nil)
    end

    it "raises if connection key requested with unknown select_by argument" do
      expect { part.connection_key(mode: :something_weird) }.to raise_error(ArgumentError, "unknown mode")
    end

    # TODO: need more tests here to verify correct follower index is chosen
    # waiting until I understand more about how exactly we want that logic to work
  end
end
