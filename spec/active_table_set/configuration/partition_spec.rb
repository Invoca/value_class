require 'spec_helper'

describe ActiveTableSet::Configuration::Partition do
  let(:db_config) { ActiveTableSet::Configuration::DatabaseConfig.new(username: "tester", password: "verysecure", host: "localhost", timeout: 5)  }

  let(:leader)    { { :host => "127.0.0.8",  :username => "tester",  :password => "verysecure",  :timeout => 2, :database => "main" } }
  let(:follower1) { { :host => "127.0.0.9",  :username => "tester1", :password => "verysecure1", :timeout => 2, :database => "replication1" } }
  let(:follower2) { { :host => "127.0.0.10", :username => "tester2", :password => "verysecure2", :timeout => 2, :database => "replication2" } }
  let(:cfg)       { { :leader => leader, :followers => [follower1, follower2] } }

  let(:part)      { ActiveTableSet::Configuration::Partition.new( leader: leader) }

  context "config" do
    it "provides a leader" do
      config = ActiveTableSet::Configuration::Partition.new(cfg)
      leader = config.leader

      expect(leader.host).to     eq("127.0.0.8")
      expect(leader.username).to eq("tester")
      expect(leader.password).to eq("verysecure")
      expect(leader.timeout).to  eq(2)
    end

    it "provides an array of followers" do
      config = ActiveTableSet::Configuration::Partition.new(cfg)

      followers = config.followers
      follower1 = followers.first
      follower2 = followers.last

      expect(follower1.host).to     eq("127.0.0.9")
      expect(follower1.username).to eq("tester1")
      expect(follower1.password).to eq("verysecure1")

      expect(follower2.host).to     eq("127.0.0.10")
      expect(follower2.username).to eq("tester2")
      expect(follower2.password).to eq("verysecure2")
    end

    it "can be progressively constructed" do
      config = ActiveTableSet::Configuration::Partition.config do |part|
        part.partition_key = 'alpha'

        part.leader do |leader|
          leader.host = "127.0.0.8"
          leader.username = "tester"
          leader.password = "verysecure"
          leader.timeout  = 2
          leader.database ="main"
        end

        part.follower do |follower|
          follower.host = "127.0.0.9"
          follower.username = "tester1"
          follower.password = "verysecure1"
          follower.timeout  = 2
          follower.database ="replication1"
        end

        part.follower do |follower|
          follower.host = "127.0.0.10"
          follower.username = "tester2"
          follower.password = "verysecure2"
          follower.timeout  = 2
          follower.database ="replication2"
        end
      end

      expect(config.partition_key).to eq("alpha")
      leader    = config.leader
      follower1 = config.followers.first
      follower2 = config.followers.last
      expect(leader.host).to     eq("127.0.0.8")
      expect(leader.username).to eq("tester")
      expect(leader.password).to eq("verysecure")

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
      expect { ActiveTableSet::Configuration::Partition.new }.to raise_error(ArgumentError, "must provide a leader")
    end
  end

  context "connections" do
    it "provides a leader connection key for write access" do
      database_config = part.database_config(access_mode: :write)
      expect(database_config).to eq(part.leader)
    end

    it "provides a leader connection key for read access" do
      database_config = part.database_config(access_mode: :read)
      expect(database_config).to eq(part.leader)
    end

    it "provides a chosen database config for balanced read access" do
      expect(ActiveTableSet::Configuration::Partition).to receive(:pid).and_return(0)
      part2 = ActiveTableSet::Configuration::Partition.new(cfg)
      database_config = part2.database_config(access_mode: :balanced)
      expect(database_config.host).to eq(leader[:host])
    end

    it "provides a chosen follower connection key for balanced read access" do
      expect(ActiveTableSet::Configuration::Partition).to receive(:pid).and_return(1)
      part2 = ActiveTableSet::Configuration::Partition.new(cfg)
      database_config = part2.database_config(access_mode: :balanced)
      expect(database_config.host).to eq(follower1[:host])
    end

    it "returns leader for balanced follower connection key if no followers" do
      database_config = part.database_config(access_mode: :balanced)
      expect(database_config.host).to eq(leader[:host])
    end

    it "raises if connection key requested with unknown access_mode" do
      expect { part.database_config(access_mode: :something_weird) }.to raise_error(ArgumentError, "unknown access_mode")
    end
  end
end
