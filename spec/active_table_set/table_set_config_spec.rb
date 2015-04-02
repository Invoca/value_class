require 'spec_helper'

describe ActiveTableSet::TableSetConfig do
  context "config" do
    let(:leader)        { { :host => "127.0.0.8",  :username => "tester",  :password => "verysecure",  :timeout => 2, :database => "main" } }
    let(:follower1)     { { :host => "127.0.0.9",  :username => "tester1", :password => "verysecure1", :timeout => 2, :database => "replication1" } }
    let(:follower2)     { { :host => "127.0.0.10", :username => "tester2", :password => "verysecure2", :timeout => 2, :database => "replication2" } }
    let(:partition_cfg) { { :leader => leader, :followers => [follower1, follower2] } }
    let(:table_set_cfg) { { :name => "test_ts", :partitions => [partition_cfg], :readable => ["zebras", "rhinos", "lions"], :writeable => ["tourists", "guides"] } }
    let(:config)        { ActiveTableSet::TableSetConfig.new(config: table_set_cfg) }

    it "provides an array of Partition Configs" do
      expect(config.partition_count).to eq(1)
    end

    it "provides an array of Readable Tables" do
      expect(config.writeable_tables.length).to eq(2)
    end

    it "provides an array of Writable Table" do
      expect(config.readable_tables.length).to eq(3)
    end
  end
end
