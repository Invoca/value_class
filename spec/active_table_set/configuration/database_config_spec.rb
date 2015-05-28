require 'spec_helper'

describe ActiveTableSet::Configuration::DatabaseConfig do
  context "config" do
    it "provides reasonable defaults" do
      spec = ActiveTableSet::Configuration::DatabaseConfig.new.specification
      expect(spec[:connect_timeout]).to eq(5)
      expect(spec[:read_timeout]).to    eq(2)
      expect(spec[:write_timeout]).to   eq(2)
      expect(spec[:encoding]).to        eq("utf8")
      expect(spec[:collation]).to       eq("utf8_general_ci")
      expect(spec[:pool]).to            eq(5)
      expect(spec[:reconnect]).to       eq(true)
      expect(spec[:host]).to            eq("localhost")
      expect(spec[:adapter]).to         eq("mysql2")
      expect(spec[:username]).to        eq("")
      expect(spec[:password]).to        eq("")
      expect(spec[:database]).to        eq("")
    end

    it "provides a pool key based on certain fields" do
      key = ActiveTableSet::Configuration::DatabaseConfig.new(host: "some.ip", username: "test_user", password: "secure_pwd", timeout: 10)
      expect(key.host).to     eq("some.ip")
      expect(key.username).to eq("test_user")
      expect(key.password).to eq("secure_pwd")
      expect(key.timeout).to  eq(10)
    end

    it "has a name" do
      name = ActiveTableSet::Configuration::DatabaseConfig.new(adapter: "mysql2").name
      expect(name).to eq("mysql2_connection")
    end
  end

  let(:ip)       { "127.0.0.1" }
  let(:username) { "test_user" }
  let(:password) { "test_password" }
  let(:timeout)  { 5 }
  let(:init_params) { {host: ip, username: username, password: password, timeout: timeout} }

  context "comparison" do
    it "considers two keys equal if ip, username, password, and timeout all match" do
      key1 = ActiveTableSet::Configuration::DatabaseConfig.new(host: ip, username: username, password: password, timeout: timeout)
      key2 = ActiveTableSet::Configuration::DatabaseConfig.new(host: ip, username: username, password: password, timeout: timeout)
      expect(key1).to eq(key2)
    end

    it "considers two keys not equal if hostes do not match" do
      key1 = ActiveTableSet::Configuration::DatabaseConfig.new(host: ip, username: username, password: password, timeout: timeout)
      key2 = ActiveTableSet::Configuration::DatabaseConfig.new(host: "127.0.0.2", username: username, password: password, timeout: timeout)
      expect(key1).not_to eq(key2)
    end

    it "considers two keys not equal if usernames do not match" do
      key1 = ActiveTableSet::Configuration::DatabaseConfig.new(host: ip, username: username, password: password, timeout: timeout)
      key2 = ActiveTableSet::Configuration::DatabaseConfig.new(host: ip, username: "something", password: password, timeout: timeout)
      expect(key1).not_to eq(key2)
    end

    it "considers two keys not equal if passwords do not match" do
      key1 = ActiveTableSet::Configuration::DatabaseConfig.new(host: ip, username: username, password: password, timeout: timeout)
      key2 = ActiveTableSet::Configuration::DatabaseConfig.new(host: ip, username: username, password: "something", timeout: timeout)
      expect(key1).not_to eq(key2)
    end

    it "considers two keys not equal if timeouts do not match" do
      key1 = ActiveTableSet::Configuration::DatabaseConfig.new(host: ip, username: username, password: password, timeout: timeout)
      key2 = ActiveTableSet::Configuration::DatabaseConfig.new(host: ip, username: username, password: password, timeout: 6)
      expect(key1).not_to eq(key2)
    end
  end

  context "clone and reset timeout" do
    it "cleanly clones itself and its associated config" do
      key1 = ActiveTableSet::Configuration::DatabaseConfig.new(host: ip, username: username, password: password, timeout: timeout)
      key2 = key1.clone_with_new_timeout(15)

      expect(key1.timeout).to eq(timeout)

      expect(key2.timeout).to eq(15)
    end
  end

end
