require 'spec_helper'

describe ActiveTableSet::DatabaseServer do
  context "constructor" do
    it "raises on nil config" do
      expect { ActiveTableSet::DatabaseServer.new(db_config: nil, server_type: :leader, pool_manager: true) }.to raise_error(RuntimeError, "Must pass a configuration")
    end

    it "raises on nil type" do
      expect { ActiveTableSet::DatabaseServer.new(db_config: true, server_type: nil, pool_manager: true) }.to raise_error(RuntimeError, "Must pass a type")
    end

    it "raises on nil pool manager" do
      expect { ActiveTableSet::DatabaseServer.new(db_config: true, server_type: :leader, pool_manager: nil) }.to raise_error(RuntimeError, "Must pass a pool manager")
    end
  end

  context "accessors" do
    let(:db_server) { ActiveTableSet::DatabaseServer.new(db_config: true, server_type: :leader, pool_manager: true) }

    it 'has a database connection type' do
      expect(db_server.server_type).to eq(:leader)
    end

    it 'has a connection name' do
      expect(db_server.connection_name).to eq("leader_connection")
    end

    it 'has a database connection config' do
      expect(db_server.db_config).to eq(true)
    end

    it 'has a pool manager' do
      expect(db_server.pool_manager).to eq(true)
    end
  end

  context "pool manager" do
    # TODO: add PoolManager class to gem
  end

  context "connections" do
    # TODO: add PoolManager class to gem
  end
end
