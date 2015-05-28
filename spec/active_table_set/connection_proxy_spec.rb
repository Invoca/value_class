require 'spec_helper'

describe ActiveTableSet::ConnectionProxy do
  context "construction" do
    it "raises on missing config parameter" do
      expect { ActiveTableSet::ConnectionProxy.new }.to raise_error(ArgumentError, "missing keyword: config")
    end
  end

  context "delegation to connection" do
    let(:proxy) { ActiveTableSet::ConnectionProxy.new(config: large_table_set) }
    let(:mgr)   { proxy.send(:pool_manager) }

    it "delegates all AbstractAdapter methods to the current connection" do
      proxy.set_default_table_set(table_set_name: :common)

      connection = double("connection")
      pool = double("pool")
      expect(mgr).to receive(:create_pool).and_return(pool)
      expect(pool).to receive(:connection).exactly(2).times { connection }

      expect(connection).to receive(:clear_cache!).and_return("cleared!")
      expect(proxy.clear_cache!).to eq("cleared!")

      expect(connection).to receive(:schema_cache).and_return("schema")
      expect(proxy.schema_cache).to eq("schema")
    end
  end

  context "using PoolManager" do
    let(:proxy) { ActiveTableSet::ConnectionProxy.new(config: large_table_set) }
    let(:mgr)   { proxy.send(:pool_manager) }

    it "gets a new pool from PoolManager" do
      expect(mgr).to receive(:create_pool).and_return("stand-in_for_actual_pool")

      leader_key = proxy.send(:database_config, table_set: :common, access_mode: :write)
      pool = proxy.send(:pool, leader_key)
      expect(mgr.pool_count).to eq(1)
      expect(pool).to eq("stand-in_for_actual_pool")
    end

    it "gets same pool from PoolManager for same pool key" do
      expect(mgr).to receive(:create_pool).once.and_return("stand-in_for_actual_pool")

      leader_key = proxy.send(:database_config, table_set: :common, access_mode: :write)
      pool = proxy.send(:pool, leader_key)
      expect(mgr.pool_count).to eq(1)
      expect(pool).to eq("stand-in_for_actual_pool")

      pool2 = proxy.send(:pool, leader_key)
      expect(pool).to eq(pool2)
    end

    it "uses different pools for connections with different timeouts" do
      leader_pool_2 = double("leader_timeout_2_pool")
      expect(leader_pool_2).to receive(:connection).exactly(4).times { "leader_timeout_2_connection" }
      expect(leader_pool_2).to receive(:release_connection).twice { true }

      follower_pool_2 = double("follower_timeout_2_pool")
      expect(follower_pool_2).to receive(:connection).exactly(2).times { "follower_timeout_2_connection" }
      expect(follower_pool_2).to receive(:release_connection) { true }

      leader_pool_5 = double("leader_timeout_5_pool")
      expect(leader_pool_5).to receive(:connection).exactly(4).times { "leader_timeout_5_connection" }
      expect(leader_pool_5).to receive(:release_connection).twice { true }

      follower_pool_5 = double("follower_timeout_5_pool")
      expect(follower_pool_5).to receive(:connection).exactly(2).times { "follower_timeout_5_connection" }
      expect(follower_pool_5).to receive(:release_connection) { true }

      allow(ActiveTableSet::Configuration::Partition).to receive(:pid) { 1 }

      expect(mgr).to receive(:create_pool).exactly(4).times.and_return(leader_pool_2, follower_pool_2, leader_pool_5, follower_pool_5)

      proxy.using(table_set: :common, access_mode: :write) do
        connection = proxy.connection
        expect(connection).to eq("leader_timeout_2_connection")
      end

      proxy.using(table_set: :common, access_mode: :read) do
        connection = proxy.connection
        expect(connection).to eq("leader_timeout_2_connection")
      end

      proxy.using(table_set: :common, access_mode: :balanced) do
        connection = proxy.connection
        expect(connection).to eq("follower_timeout_2_connection")
      end

      proxy.using(table_set: :common, access_mode: :write, timeout: 5) do
        connection = proxy.connection
        expect(connection).to eq("leader_timeout_5_connection")
      end

      proxy.using(table_set: :common, access_mode: :balanced, timeout: 5) do
        connection = proxy.connection
        expect(connection).to eq("follower_timeout_5_connection")
      end

      proxy.using(table_set: :common, access_mode: :read, timeout: 5) do
        connection = proxy.connection
        expect(connection).to eq("leader_timeout_5_connection")
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
      pool_dbl_1 = double("pool_dbl_1")
      expect(pool_dbl_1).to receive(:connection).and_return( "connection1" )
      expect(pool_dbl_1).to receive(:release_connection) { true }

      pool_dbl_2 = double("pool_dbl_2")
      expect(pool_dbl_2).to receive(:connection).and_return( "connection2" )
      expect(pool_dbl_2).to receive(:release_connection) { true }

      expect(mgr).to receive(:create_pool).twice.and_return(pool_dbl_1, pool_dbl_2)

      proxy.using(table_set: :common, access_mode: :read, timeout: 5) do
        pool1 = proxy.send(:pool, proxy.send(:thread_database_config))
        proxy.using(table_set: :common, access_mode: :read, timeout: 10) do
          pool2 = proxy.send(:pool, proxy.send(:thread_database_config))
          expect(pool1).to_not eq(pool2)
        end
      end
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
