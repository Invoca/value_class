require 'spec_helper'

describe ActiveTableSet::Configuration::DatabaseConnection do
  context "config" do
    it "can be constructed" do
      key = ActiveTableSet::Configuration::DatabaseConnection.new(host: "some.ip", read_write_username: "test_user", read_write_password: "secure_pwd")
      expect(key.host).to     eq("some.ip")
      expect(key.read_write_username).to eq("test_user")
      expect(key.read_write_password).to eq("secure_pwd")
    end

    it "can generate a connection specification" do
      connection = ActiveTableSet::Configuration::DatabaseConnection.new(
          host: "some.ip",
          read_write_username: "test_user",
          read_write_password: "secure_pwd",
          database: "my_database")

      specification = connection.pool_key(alternates: [], timeout: 30)

      expected = {
          "host"=>"some.ip",
          "database"=>"my_database",
          "username"=>"test_user",
          "password"=>"secure_pwd",
          "connect_timeout"=>5,
          "read_timeout"=>30,
          "write_timeout"=>30,
          "encoding"=>"utf8",
          "collation"=>"utf8_general_ci",
          "adapter"=>"mysql2",
          "pool"=>5,
          "reconnect"=>true
      }

      expect(specification.to_hash).to eq(expected)
    end

    it "uses readonly attributes if not in write mode" do
      connection = ActiveTableSet::Configuration::DatabaseConnection.new(
          host: "some.ip",
          read_only_username: "test_user",
          read_only_password: "secure_pwd",
          read_write_username: "not this one",
          read_write_password: "don't pick me",
          database: "my_database" )

      specification = connection.pool_key(alternates: [], access_mode: :read, timeout: 10)

      expect(specification.username).to eq("test_user")
      expect(specification.password).to eq("secure_pwd")
    end

    it "finds values from the defaults if not provided locally" do
      connection = ActiveTableSet::Configuration::DatabaseConnection.new(
          host: "some.ip",
          read_only_username: "test_user",
          read_only_password: "secure_pwd",
          read_write_username: "not this one",
          read_write_password: "don't pick me",
          database: "my_database")

      specification = connection.pool_key(alternates: [], timeout: 10)
      expect(specification.adapter).to eq("mysql2")
    end

    it "finds values from alternates if not provided locally" do
      connection = ActiveTableSet::Configuration::DatabaseConnection.new(
          host: "some.ip",
          read_write_username: "test_user",
          read_write_password: "secure_pwd" )

      alternate = ActiveTableSet::Configuration::DatabaseConnection.new(database: "my_database")

      specification = connection.pool_key(alternates: [alternate], timeout: 10)
      expect(specification.database).to eq("my_database")
    end

    it "finds the values from alternates in the order provided" do
      connection = ActiveTableSet::Configuration::DatabaseConnection.new(
          host: "some.ip",
          read_write_username: "test_user",
          read_write_password: "secure_pwd")

      alternate1 = ActiveTableSet::Configuration::DatabaseConnection.new(database: "my_database")
      alternate2 = ActiveTableSet::Configuration::DatabaseConnection.new(database: "not_my_database")

      specification = connection.pool_key(alternates: [alternate1,alternate2], timeout: 10)
      expect(specification.database).to eq("my_database")
    end

    it "raises an error if it cannot find the value" do
      connection = ActiveTableSet::Configuration::DatabaseConnection.new(
          host: "some.ip",
          read_write_username: "test_user",
          read_write_password: "secure_pwd")

      expect { connection.pool_key(alternates:[], context: "foo", timeout: 10) }.to raise_error(ArgumentError, "could not resolve database value for foo")
    end

  end

end
