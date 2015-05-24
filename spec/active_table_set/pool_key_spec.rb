require 'spec_helper'

describe ActiveTableSet::PoolKey do
  let(:ip)       { "127.0.0.1" }
  let(:username) { "test_user" }
  let(:password) { "test_password" }
  let(:timeout)  { 5 }
  let(:config)   { ActiveTableSet::DatabaseConfig.new(timeout: timeout) }
  let(:init_params) { {host: ip, username: username, password: password, timeout: timeout, config: config} }

  context "constructor" do
    it "takes database ip, username, password, and timeout as params" do
      key = ActiveTableSet::PoolKey.new(host: ip, username: username, password: password, timeout: timeout, config: config)

      expect(key.host).to eq(ip)
      expect(key.username).to eq(username)
      expect(key.password).to eq(password)
      expect(key.timeout).to eq(timeout)
    end

    [:host, :username, :password, :timeout, :config].each do |attr|
      it "raises if not passed #{attr}" do
        init_params.delete(attr)
        expect { ActiveTableSet::PoolKey.new(init_params) }.to raise_error(ArgumentError, "must provide a value for #{attr}")
      end
    end
  end

  context "comparison" do
    it "considers two keys equal if ip, username, password, and timeout all match" do
      key1 = ActiveTableSet::PoolKey.new(host: ip, username: username, password: password, timeout: timeout, config: config)
      key2 = ActiveTableSet::PoolKey.new(host: ip, username: username, password: password, timeout: timeout, config: config)
      expect(key1).to eq(key2)
    end

    it "considers two keys not equal if hostes do not match" do
      key1 = ActiveTableSet::PoolKey.new(host: ip, username: username, password: password, timeout: timeout, config: config)
      key2 = ActiveTableSet::PoolKey.new(host: "127.0.0.2", username: username, password: password, timeout: timeout, config: config)
      expect(key1).not_to eq(key2)
    end

    it "considers two keys not equal if usernames do not match" do
      key1 = ActiveTableSet::PoolKey.new(host: ip, username: username, password: password, timeout: timeout, config: config)
      key2 = ActiveTableSet::PoolKey.new(host: ip, username: "something", password: password, timeout: timeout, config: config)
      expect(key1).not_to eq(key2)
    end

    it "considers two keys not equal if passwords do not match" do
      key1 = ActiveTableSet::PoolKey.new(host: ip, username: username, password: password, timeout: timeout, config: config, config: config)
      key2 = ActiveTableSet::PoolKey.new(host: ip, username: username, password: "something", timeout: timeout, config: config)
      expect(key1).not_to eq(key2)
    end

    it "considers two keys not equal if timeouts do not match" do
      key1 = ActiveTableSet::PoolKey.new(host: ip, username: username, password: password, timeout: timeout, config: config)
      key2 = ActiveTableSet::PoolKey.new(host: ip, username: username, password: password, timeout: 6, config: config)
      expect(key1).not_to eq(key2)
    end
  end

  context "as hash key" do
    it "finds matching hash entry on equivalent keys" do
      key1 = ActiveTableSet::PoolKey.new(host: ip, username: username, password: password, timeout: timeout, config: config)
      key2 = ActiveTableSet::PoolKey.new(host: ip, username: username, password: password, timeout: 6, config: config)

      test_hash = { key1 => "value1", key2 => "value2" }

      key3 = ActiveTableSet::PoolKey.new(host: ip, username: username, password: password, timeout: timeout, config: config)
      key4 = ActiveTableSet::PoolKey.new(host: ip, username: username, password: password, timeout: 6, config: config)

      expect(test_hash[key3]).to eq("value1")
      expect(test_hash[key1]).to eq("value1")
      expect(test_hash[key4]).to eq("value2")
      expect(test_hash[key2]).to eq("value2")
    end
  end

  context "clone and reset timeout" do
    it "cleanly clones itself and its associated config" do
      key1 = ActiveTableSet::PoolKey.new(host: ip, username: username, password: password, timeout: timeout, config: config)
      key2 = key1.clone_with_new_timeout(15)

      expect(key1.config.timeout).to eq(timeout)
      expect(key1.timeout).to eq(timeout)

      expect(key2.config.timeout).to eq(15)
      expect(key2.timeout).to eq(15)
    end
  end
end
