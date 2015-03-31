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

    it 'has a database connection config' do
      expect(db_server.db_config).to eq(true)
    end
  end

  context "connections" do
    let(:db_server) { ActiveTableSet::DatabaseServer.new(db_config: true, server_type: :leader, pool_manager: true) }

    # TODO: figure out how to stub the calls to pool
    # connection is an AbstractAdapter (or object conforming to its interface)
  end
end
