require 'spec_helper'

describe ActiveTableSet::PartitionConfig do
  context "config" do
    let(:leader)    { { :host => "127.0.0.8",  :username => "tester",  :password => "verysecure",  :timeout => 2, :database => "main" } }
    let(:follower1) { { :host => "127.0.0.9",  :username => "tester1", :password => "verysecure1", :timeout => 2, :database => "replication1" } }
    let(:follower2) { { :host => "127.0.0.10", :username => "tester2", :password => "verysecure2", :timeout => 2, :database => "replication2" } }
    let(:cfg)       { { :leader => leader, :followers => [follower1, follower2] } }

    it "provides a leader PoolKey" do
      config = ActiveTableSet::PartitionConfig.new(cfg)
      leader = config.leader_key

      expect(leader.host).to     eq("127.0.0.8")
      expect(leader.username).to eq("tester")
      expect(leader.password).to eq("verysecure")
      expect(leader.timeout).to  eq(2)
    end

    it "provides an array of followers PoolKeys" do
      config = ActiveTableSet::PartitionConfig.new(cfg)

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
end
