require 'spec_helper'

describe ActiveTableSet::TableSet do
  let(:leader)    { { :host => "127.0.0.8",  :username => "tester",  :password => "verysecure",  :timeout => 2, :database => "main" } }
  let(:follower1) { { :host => "127.0.0.9",  :username => "tester1", :password => "verysecure1", :timeout => 2, :database => "replication1" } }
  let(:follower2) { { :host => "127.0.0.10", :username => "tester2", :password => "verysecure2", :timeout => 2, :database => "replication2" } }
  let(:partition_cfg) { { :leader => leader, :followers => [follower1, follower2] } }
  let(:table_set_cfg) { { :name => "test_ts", :partitions => [partition_cfg], :readable => ["zebras", "rhinos", "lions"], :writeable => ["tourists", "guides"] } }
  let(:ts_config) { ActiveTableSet::TableSetConfig.new(config: table_set_cfg) }

  context "construction" do
    it "raises if not passed a config" do
      expect { ActiveTableSet::TableSet.new }.to raise_error(ArgumentError, "missing keyword: config")
    end
  end

  context "connections" do
    it "selects correct partition to grab a connection key from" do
      table_set = ActiveTableSet::TableSet.new(config: ts_config)
      table_set.connection_key(access_mode: :write, partition_id: 0)
    end
  end

  context "readable and writeable table sets" do
    it "keeps an array of readable tables" do
      table_set = ActiveTableSet::TableSet.new(config: ts_config)
      tabs = table_set.readable_tables
      expect(tabs[0]).to eq("zebras")
      expect(tabs[1]).to eq("rhinos")
      expect(tabs[2]).to eq("lions")
    end

    it "keeps an array of writeable tables" do
      table_set = ActiveTableSet::TableSet.new(config: ts_config)
      tabs = table_set.writeable_tables
      expect(tabs[0]).to eq("tourists")
      expect(tabs[1]).to eq("guides")
    end
  end
end
