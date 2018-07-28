# frozen_string_literal: true

require 'spec_helper'

describe ActiveTableSet::Extensions::ConnectionHandlerExtension do

  let(:connection_handler) { StubConnectionHandler.new }

  let(:default_spec) do
    ActiveRecord::ConnectionAdapters::ConnectionSpecification.new(
      ActiveTableSet::Configuration::DatabaseConnection.new(
        host: "some.ip",
        read_write_username: "test_user",
        read_write_password: "secure_pwd",
        database: "my_database").to_hash,
      'stub_client_connection'
    ).tap do |connection_specification|
      connection_specification.instance_variable_set(:@table_set, :ringswitch)
    end
  end

  let(:alternate_spec) do
    ActiveRecord::ConnectionAdapters::ConnectionSpecification.new(
      ActiveTableSet::Configuration::DatabaseConnection.new(
        host: "some_other.ip",
        read_write_username: "test_user2",
        read_write_password: "secure_pwd2",
        database: "my_database2").to_hash,
      'some_method'
    ).tap do |connection_specification|
      connection_specification.instance_variable_set(:@table_set, :ringswitch)
    end
  end

  context "connection handler extension" do
    it "has thread variables" do
      connection_handler.thread_connection_spec = :value
      expect(connection_handler.thread_connection_spec).to eq(:value)
    end

    it "returns the default connection if the thread connection spec is not set" do
      connection_handler.default_spec(default_spec)
      expect(connection_handler.current_config).to eq(default_spec.config)
    end

    it "returns the test_scenario_connection_spec if that is set but the thread connection is not set" do
      connection_handler.test_scenario_connection_spec = default_spec
      expect(connection_handler.current_config).to eq(default_spec.config)
    end

    it "returns the thread connection spec when set" do
      connection_handler.default_spec(default_spec)
      connection_handler.current_spec = alternate_spec
      expect(connection_handler.current_config).to eq(alternate_spec.config)
    end

    it "adds the access policy to the connection if connection monitoring is required" do
      expect(ActiveTableSet).to receive(:enforce_access_policy?) { true }
      connection_handler.default_spec(default_spec)
      connection = connection_handler.connection
      expect(connection.respond_to?(:show_error_in_bars)).to eq(true)
    end

    it "does not add the access policy to the connection if connection monitoring is not required" do
      expect(ActiveTableSet).to receive(:enforce_access_policy?) { false }
      connection_handler.default_spec(default_spec)
      connection = connection_handler.connection
      expect(connection.respond_to?(:show_error_in_bars)).to eq(false)
    end

    it "has a pool for spec method" do
      connection_handler.default_spec(default_spec)
      expect(connection_handler.pool_for_spec(default_spec).spec.config).to eq(default_spec.config)
    end

    it "suppresses remove_connection for active record base" do
      connection_handler.remove_connection(ActiveRecord::Base)
      connection_handler.remove_connection(ActiveTableSet)

      expect(connection_handler.remove_calls).to eq(["ActiveTableSet"])
    end

    context "reap_connections" do
      it "calls reap_connections on each connection pool when defined" do
        2.times do |i|
          pool = Object.new
          expect(pool).to receive(:reap_connections)
          connection_handler.connection_pools[i] = pool
        end

        connection_handler.reap_connections
      end

      it "doesn't call reap_connections on each connection pool when not defined" do
        2.times do |i|
          pool = Object.new
          connection_handler.connection_pools[i] = pool
        end

        connection_handler.reap_connections
      end
    end

    context "pool leaking" do
      it "does not leak pools if a connection handler mutates the connection" do
        allow(ActiveTableSet).to receive(:enforce_access_policy?) { true }

        connection_handler.default_spec(default_spec)

        # Some connection classes mutate the config.  Simulate that here.
        connection1 = connection_handler.connection
        connection1.config["flags"] = 2

        expect(connection_handler.connection_pools.count).to eq(1)

        # Need a new spec because it was mutated above...
        default_spec_2 = ActiveRecord::ConnectionAdapters::ConnectionSpecification.new(
          ActiveTableSet::Configuration::DatabaseConnection.new(
            host: "some.ip",
            read_write_username: "test_user",
            read_write_password: "secure_pwd",
            database: "my_database").to_hash,
          'some_method' )
        default_spec_2.instance_variable_set(:@table_set, :ringswitch)

        connection_handler.current_spec = default_spec_2

        connection2 = connection_handler.connection
        expect(connection_handler.connection_pools.count).to eq(1)
      end

      it "returns the same connection when accessing the same pool" do
        allow(ActiveTableSet).to receive(:enforce_access_policy?) { false }

        connection_handler.default_spec(default_spec)
        connection1 = connection_handler.connection

        connection_handler.current_spec = default_spec
        connection2 = connection_handler.connection

        expect(connection1.object_id).to eq(connection2.object_id)
      end
    end

    it "normalizes to string keys data before looking up the hash" do
      allow(ActiveTableSet).to receive(:enforce_access_policy?) { true }
      connection_handler.default_spec(default_spec)
      expect(connection_handler.connection_pools.count).to eq(1)

      # Need a new spec because it was mutated above...
      database_config = ActiveTableSet::Configuration::DatabaseConnection.new(
        host: "some.ip",
        read_write_username: "test_user",
        read_write_password: "secure_pwd",
        database: "my_database").to_hash.symbolize_keys

      default_spec_2 = ActiveRecord::ConnectionAdapters::ConnectionSpecification.new(database_config, 'some_method')
      default_spec_2.instance_variable_set(:@table_set, :ringswitch)

      connection_handler.current_spec = default_spec_2

      connection2 = connection_handler.connection
      expect(connection_handler.connection_pools.count).to eq(1)
    end

    it "ignores the flags param before looking up the hash" do
      allow(ActiveTableSet).to receive(:enforce_access_policy?) { true }
      connection_handler.default_spec(default_spec)
      expect(connection_handler.connection_pools.count).to eq(1)

      # Need a new spec because it was mutated above...
      database_config = ActiveTableSet::Configuration::DatabaseConnection.new(
        host: "some.ip",
        read_write_username: "test_user",
        read_write_password: "secure_pwd",
        database: "my_database").to_hash
      database_config["flags"] = 2

      default_spec_2 = ActiveRecord::ConnectionAdapters::ConnectionSpecification.new(database_config, 'some_method')
      default_spec_2.instance_variable_set(:@table_set, :ringswitch)

      connection_handler.current_spec = default_spec_2

      connection2 = connection_handler.connection
      expect(connection_handler.connection_pools.count).to eq(1)
    end

    it "uses the normalization in establish_connection" do
      allow(ActiveTableSet).to receive(:enforce_access_policy?) { true }
      connection_handler.default_spec(default_spec)
      expect(connection_handler.connection_pools.count).to eq(1)

      # Need a new spec because it was mutated above...
      database_config = ActiveTableSet::Configuration::DatabaseConnection.new(
        host: "some.ip",
        read_write_username: "test_user",
        read_write_password: "secure_pwd",
        database: "my_database").to_hash
      database_config["flags"] = 2

      default_spec_2 = ActiveRecord::ConnectionAdapters::ConnectionSpecification.new(database_config, 'some_method')
      default_spec_2.instance_variable_set(:@table_set, :ringswitch)

      connection_handler.establish_connection(ActiveRecord::Base, default_spec_2)
      expect(connection_handler.connection_pools.count).to eq(1)
    end

    describe "connection_pool_stats" do
      it "should return a hash of stats for table_sets that have connection_pools" do
        configure_ats_like_ringswitch
        connection_handler.default_spec(
          ActiveRecord::ConnectionAdapters::ConnectionSpecification.new(
            ActiveTableSet::Configuration::DatabaseConnection.new(
              host:                 "some.ip",
              adapter:              "fibered_mysql2",
              read_write_username:  "test_user",
              read_write_password:  "secure_pwd",
              database:             "my_database").to_hash,
            'stub_client_connection'
          ).tap do |connection_specification|
            connection_specification.instance_variable_set(:@table_set, :ringswitch)
          end
        )
        ActiveTableSet.enable

        c0 = connection_handler.connection
        fiber1 = Fiber.new { c1 = connection_handler.connection }
        fiber2 = Fiber.new { c2 = connection_handler.connection }
        fiber3 = Fiber.new { c3 = connection_handler.connection }
        fiber1.resume # bump in_use and allocated to 2
        fiber2.resume # bump in_use and allocated to 3
        fiber3.resume # bump in_use and allocated to 4

        stats = connection_handler.connection_pool_stats

        expect(stats).to eq(
                           ringswitch:      { allocated: 4, in_use: 4 }
                         )
      end
    end
  end
end
