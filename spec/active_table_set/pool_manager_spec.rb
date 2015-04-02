require 'spec_helper'

describe ActiveTableSet::PoolManager do
  context "pool creation" do
    let(:ip)        { "127.0.0.1" }
    let(:username)  { "test_user" }
    let(:password)  { "test_password" }
    let(:timeout)   { 5 }
    let(:db_config) { ActiveTableSet::DatabaseConfig.new(username: username, password: password, host: ip, timeout: timeout) }
    let(:mgr)       { ActiveTableSet::PoolManager.new }
    let(:key)       { ActiveTableSet::PoolKey.new(host: ip, username: username, password: password, timeout: timeout, config: db_config) }

    it "creates a new pool if one with the requested key does not exist" do
      allow(mgr).to receive(:create_pool).and_return(true)
      expect(mgr.pool_count).to eq(0)

      mgr.get_pool(key: key)
      expect(mgr.pool_count).to eq(1)
    end

    it "returns an existing pool if one with the requested key already exists" do
      allow(mgr).to receive(:create_pool).and_return(true)
      expect(mgr.pool_count).to eq(0)

      pool1 = mgr.get_pool(key: key)
      pool2 = mgr.get_pool(key: key)
      expect(pool1).to eq(pool2)
      expect(mgr.pool_count).to eq(1)
    end
  end
end
