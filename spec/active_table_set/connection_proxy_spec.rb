require 'spec_helper'

describe ActiveTableSet::ConnectionProxy do
  let(:leader)    { { :host => "127.0.0.8",  :username => "tester",  :password => "verysecure",  :timeout => 2, :database => "main" } }
  let(:follower1) { { :host => "127.0.0.9",  :username => "tester1", :password => "verysecure1", :timeout => 2, :database => "replication1" } }
  let(:follower2) { { :host => "127.0.0.10", :username => "tester2", :password => "verysecure2", :timeout => 2, :database => "replication2" } }
  let(:partition_cfg) { { :leader => leader, :followers => [follower1, follower2] } }
  let(:table_set_cfg) { { :name => "test_ts", :partitions => [partition_cfg], :readable => ["zebras", "rhinos", "lions"], :writeable => ["tourists", "guides"] } }
  let(:main_cfg) { { :table_sets => [table_set_cfg] } }

  context "construction" do
    it "raises on missing config parameter" do
      expect { ActiveTableSet::ConnectionProxy.new }.to raise_error(ArgumentError, "missing keyword: config")
    end
  end

  context "table set construction" do
    it "constructs a hash of table sets based on configuration hash" do
      proxy = ActiveTableSet::ConnectionProxy.new(config: main_cfg)
      expect(proxy.table_set_names.length).to eq(1)
      expect(proxy.table_set_names[0]).to eq("test_ts")
    end
  end

end
