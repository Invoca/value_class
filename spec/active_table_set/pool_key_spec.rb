require 'spec_helper'

describe ActiveTableSet::PoolKey do
  context "constructor" do
    let(:ip)       { "127.0.0.1" }
    let(:username) { "test_user" }
    let(:password) { "test_password" }
    let(:timeout)  { 5 }

    it "takes database ip, username, password, and timeout as params" do
      key = ActiveTableSet::PoolKey.new(host: ip, username: username, password: password, timeout: timeout)

      expect(key.host).to eq(ip)
      expect(key.username).to eq(username)
      expect(key.password).to eq(password)
      expect(key.timeout).to eq(timeout)
    end

    it "raises if not passed an host" do
      expect { ActiveTableSet::PoolKey.new(username: username, password: password, timeout: timeout) }.to raise_error(RuntimeError, "Must provide a host")
    end

    it "raises if not passed a username" do
      expect { ActiveTableSet::PoolKey.new(host: ip, password: password, timeout: timeout) }.to raise_error(RuntimeError, "Must provide a username")
    end

    it "raises if not passed a password" do
      expect { ActiveTableSet::PoolKey.new(host: ip, username: username, timeout: timeout) }.to raise_error(RuntimeError, "Must provide a password")
    end

    it "raises if not passed a timeout" do
      expect { ActiveTableSet::PoolKey.new(host: ip, username: username, password: password) }.to raise_error(RuntimeError, "Must provide a timeout")
    end
  end

  context "comparison" do
    let(:ip)       { "127.0.0.1" }
    let(:username) { "test_user" }
    let(:password) { "test_password" }
    let(:timeout)  { 5 }

    it "should consider two keys equal if ip, username, password, and timeout all match" do
      key1 = ActiveTableSet::PoolKey.new(host: ip, username: username, password: password, timeout: timeout)
      key2 = ActiveTableSet::PoolKey.new(host: ip, username: username, password: password, timeout: timeout)
      expect(key1).to eq(key2)
    end

    it "should consider two keys not equal if hostes do not match" do
      key1 = ActiveTableSet::PoolKey.new(host: ip, username: username, password: password, timeout: timeout)
      key2 = ActiveTableSet::PoolKey.new(host: "127.0.0.2", username: username, password: password, timeout: timeout)
      expect(key1).not_to eq(key2)
    end

    it "should consider two keys not equal if usernames do not match" do
      key1 = ActiveTableSet::PoolKey.new(host: ip, username: username, password: password, timeout: timeout)
      key2 = ActiveTableSet::PoolKey.new(host: ip, username: "something", password: password, timeout: timeout)
      expect(key1).not_to eq(key2)
    end

    it "should consider two keys not equal if passwords do not match" do
      key1 = ActiveTableSet::PoolKey.new(host: ip, username: username, password: password, timeout: timeout)
      key2 = ActiveTableSet::PoolKey.new(host: ip, username: username, password: "something", timeout: timeout)
      expect(key1).not_to eq(key2)
    end

    it "should consider two keys not equal if timeouts do not match" do
      key1 = ActiveTableSet::PoolKey.new(host: ip, username: username, password: password, timeout: timeout)
      key2 = ActiveTableSet::PoolKey.new(host: ip, username: username, password: password, timeout: 6)
      expect(key1).not_to eq(key2)
    end
  end
end
