require 'spec_helper'

describe ActiveTableSet::DatabaseConfig do
  context "constructor" do
    it "provides reasonable defaults" do
      spec = ActiveTableSet::DatabaseConfig.new.specification
      expect(spec[:connect_timeout]).to eq(5)
      expect(spec[:read_timeout]).to eq(2)
      expect(spec[:write_timeout]).to eq(2)
      expect(spec[:encoding]).to eq("utf8")
      expect(spec[:collation]).to eq("utf8_general_ci")
      expect(spec[:pool]).to eq(5)
      expect(spec[:reconnect]).to eq(true)
      expect(spec[:host]).to eq("localhost")
      expect(spec[:adapter]).to eq("mysql2")
      expect(spec[:username]).to eq("")
      expect(spec[:password]).to eq("")
      expect(spec[:database]).to eq("")
    end

    it "provides a pool key based on certain fields" do
      key = ActiveTableSet::DatabaseConfig.new(host: "some.ip", username: "test_user", password: "secure_pwd", timeout: 10).pool_key
      expect(key.host).to eq("some.ip")
      expect(key.username).to eq("test_user")
      expect(key.password).to eq("secure_pwd")
      expect(key.timeout).to eq(10)
    end

    it "has a name" do
      name = ActiveTableSet::DatabaseConfig.new(adapter: "mysql2").name
      expect(name).to eq("mysql2_connection")
    end
  end
end
