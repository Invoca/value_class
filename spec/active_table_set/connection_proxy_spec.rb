require 'spec_helper'

describe ActiveTableSet::ConnectionProxy do
  context "construction" do
    it "raises on missing config parameter" do
      expect { ActiveTableSet::ConnectionProxy.new }.to raise_error(ArgumentError, "missing keyword: config")
    end
  end

  context "delegation to connection" do
    let(:stub_client) {StubClient.new()}
    let(:stub_pool) { StubConnectionPool.new() }
    let(:proxy_with_stub_pool) do
      allow(ActiveTableSet::PoolManager).to receive(:new) { PoolManagerStub.new }
      ActiveTableSet::ConnectionProxy.new(config: large_table_set)
    end
    let(:mgr)   { proxy_with_stub_pool.send(:pool_manager) }

    it "delegates all AbstractAdapter methods to the current connection" do
      mgr.stub_pool = stub_pool
      stub_pool.stub_client = stub_client

      proxy_with_stub_pool.set_default_table_set(table_set_name: :common)

      proxy_with_stub_pool.schema_cache
      proxy_with_stub_pool.clear_cache!

      expect(stub_client.called_commands).to eq([[:schema_cache, []], [:clear_cache!, []]])
    end
  end

  context "using PoolManager" do
    let(:stub_client) {StubClient.new()}
    let(:stub_pool) { StubConnectionPool.new() }
    let(:proxy) do
      allow(ActiveTableSet::PoolManager).to receive(:new) { PoolManagerStub.new }
      ActiveTableSet::ConnectionProxy.new(config: large_table_set)
    end
    let(:mgr)   { proxy.send(:pool_manager) }

    it "returns different connections for different configurations" do
      allow(ActiveTableSet::Configuration::Partition).to receive(:pid).and_return(1)

      connection = proxy.connection
      expect(connection.config.host).to eq("10.0.0.1")

      proxy.using(table_set: :common, access_mode: :write) do
        connection = proxy.connection
        expect(connection.config.host).to eq("10.0.0.1")
      end

      proxy.using(table_set: :common, access_mode: :read) do
        expect(proxy.connection.config.host).to eq("10.0.0.1")
      end

      proxy.using(table_set: :common, access_mode: :balanced) do
        expect(proxy.connection.config.host).to eq("10.0.0.2")
      end

      proxy.using(table_set: :common, access_mode: :write, timeout: 55) do
        expect(proxy.connection.config.host).to eq("10.0.0.1")
        expect(proxy.connection.config.read_timeout).to eq(55)
        expect(proxy.connection.config.write_timeout).to eq(55)
      end

      proxy.using(table_set: :common, access_mode: :balanced, timeout: 5) do
        expect(proxy.connection.config.host).to eq("10.0.0.2")
        expect(proxy.connection.config.read_timeout).to eq(5)
        expect(proxy.connection.config.write_timeout).to eq(5)
      end

      proxy.using(table_set: :common, access_mode: :read, timeout: 5) do
        expect(proxy.connection.config.host).to eq("10.0.0.1")
        expect(proxy.connection.config.read_timeout).to eq(5)
        expect(proxy.connection.config.write_timeout).to eq(5)
      end
    end
  end

  context "handles nested blocks using thread-safe keys" do
    let(:proxy) { ActiveTableSet::ConnectionProxy.new(config: large_table_set) }
    let(:mgr)   { proxy.send(:pool_manager) }

    it "uses existing pool if new key matches current key" do
      pool_dbl_1 = double("pool_dbl_1")
      expect(pool_dbl_1).to receive(:connection).and_return( "connection1" )
      expect(pool_dbl_1).to receive(:release_connection) { true }

      expect(mgr).to receive(:create_pool).once.and_return(pool_dbl_1)

      proxy.using(table_set: :common, access_mode: :read) do
        pool1 = proxy.send(:pool, proxy.send(:thread_database_config))
        proxy.using(table_set: :common, access_mode: :read) do
          pool2 = proxy.send(:pool, proxy.send(:thread_database_config))
          expect(pool2).to eq(pool1)
        end
      end
    end

    it "uses new pool if new key does not match current key" do
      # TODO - we no longer use different connections for different timeouts.

      # pool_dbl_1 = double("pool_dbl_1")
      # expect(pool_dbl_1).to receive(:connection).and_return( "connection1" )
      # expect(pool_dbl_1).to receive(:release_connection) { true }
      #
      # pool_dbl_2 = double("pool_dbl_2")
      # expect(pool_dbl_2).to receive(:connection).and_return( "connection2" )
      # expect(pool_dbl_2).to receive(:release_connection) { true }
      #
      # expect(mgr).to receive(:create_pool).twice.and_return(pool_dbl_1, pool_dbl_2)
      # proxy.using(table_set: :common, access_mode: :read, timeout: 5) do
      #   pool1 = proxy.send(:pool, proxy.send(:thread_database_config))
      #   proxy.using(table_set: :common, access_mode: :read, timeout: 10) do
      #     pool2 = proxy.send(:pool, proxy.send(:thread_database_config))
      #     expect(pool1).to_not eq(pool2)
      #   end
      # end
    end

    # TODO: additional tests to match expectations around releasing connections in nested situations
    # (both exceptional and normal code paths) - waiting for Bob's feedback
  end

  context "setting default context without a block" do
    let(:proxy)  { ActiveTableSet::ConnectionProxy.new(config: large_table_set) }
    let(:mgr)    { proxy.send(:pool_manager) }

    it "sets a default connection key" do
      pool_dbl_1 = double("pool_dbl_1")
      expect(pool_dbl_1).to receive(:connection).and_return("connection1")

      expect(mgr).to receive(:create_pool).once.and_return(pool_dbl_1)
      proxy.send(:thread_database_config=, nil)
      proxy.set_default_table_set(table_set_name: :common)
      connection = proxy.connection

      expect(connection).to eq("connection1")
      proxy.send(:thread_database_config=, nil)
    end

    it "raises if trying to set default connection key within an existing key block" do
      pool_dbl_1 = double("pool_dbl_1")
      expect(pool_dbl_1).to receive(:connection).and_return("connection1")
      expect(pool_dbl_1).to receive(:release_connection) { true }

      expect(mgr).to receive(:create_pool).once.and_return(pool_dbl_1)

      proxy.send(:thread_database_config=, nil)
      expect {
        proxy.using(table_set: :common, access_mode: :read) do
          proxy.set_default_table_set(table_set_name: :whatever)
        end
      }.to raise_error(RuntimeError, "Can not use set_default_table_set while in the scope of an existing table set - startup only bro")
      proxy.send(:thread_database_config=, nil)
    end
  end

  context "retrieves connections with default timeout" do
    let(:proxy)  { ActiveTableSet::ConnectionProxy.new(config: large_table_set) }
    let(:mgr)    { proxy.send(:pool_manager) }

    it "for access_mode :write" do
      test_pool = double("write_pool")
      expect(test_pool).to receive(:connection).exactly(2).times { "stand-in_for_actual_connection" }
      expect(test_pool).to receive(:release_connection) { true }
      expect(mgr).to receive(:create_pool).once.and_return(test_pool)

      proxy.using(table_set: :common, access_mode: :write) do
        connection = proxy.connection
        expect(connection).to eq("stand-in_for_actual_connection")
      end
    end

    it "for access_mode :read" do
      test_pool = double("read_pool")
      expect(test_pool).to receive(:connection).exactly(2).times { "stand-in_for_actual_connection" }
      expect(test_pool).to receive(:release_connection) { true }
      expect(mgr).to receive(:create_pool).once.and_return(test_pool)

      proxy.using(table_set: :common, access_mode: :read) do
        connection = proxy.connection
        expect(connection).to eq("stand-in_for_actual_connection")
      end
    end

    it "for access_mode :balanced" do
      test_pool = double("balanced_pool")
      expect(test_pool).to receive(:connection).exactly(2).times { "stand-in_for_actual_connection" }
      expect(test_pool).to receive(:release_connection) { true }
      expect(mgr).to receive(:create_pool).once.and_return(test_pool)

      proxy.using(table_set: :common, access_mode: :balanced) do
        connection = proxy.connection
        expect(connection).to eq("stand-in_for_actual_connection")
      end
    end
  end

  context "retrieves connections with timeout over-ride" do
    let(:proxy) { ActiveTableSet::ConnectionProxy.new(config: large_table_set) }
    let(:mgr)   { proxy.send(:pool_manager) }

    it "for access_mode :write" do
      test_pool = double("write_pool")
      expect(test_pool).to receive(:connection).exactly(2).times { "stand-in_for_actual_connection" }
      expect(test_pool).to receive(:release_connection) { true }
      expect(mgr).to receive(:create_pool).once.and_return(test_pool)

      proxy.using(table_set: :common, access_mode: :write, timeout: 25) do
        connection = proxy.connection
        expect(connection).to eq("stand-in_for_actual_connection")
      end
    end

    it "for access_mode :read" do
      test_pool = double("read_pool")
      expect(test_pool).to receive(:connection).exactly(2).times { "stand-in_for_actual_connection" }
      expect(test_pool).to receive(:release_connection) { true }
      expect(mgr).to receive(:create_pool).once.and_return(test_pool)

      proxy.using(table_set: :common, access_mode: :read, timeout: 25) do
        connection = proxy.connection
        expect(connection).to eq("stand-in_for_actual_connection")
      end
    end

    it "for access_mode :balanced" do
      test_pool = double("balanced_pool")
      expect(test_pool).to receive(:connection).exactly(2).times { "stand-in_for_actual_connection" }
      expect(test_pool).to receive(:release_connection) { true }
      expect(mgr).to receive(:create_pool).once.and_return(test_pool)

      proxy.using(table_set: :common, access_mode: :balanced, timeout: 25) do
        connection = proxy.connection
        expect(connection).to eq("stand-in_for_actual_connection")
      end
    end
  end
end
