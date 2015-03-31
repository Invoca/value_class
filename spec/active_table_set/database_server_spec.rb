require 'spec_helper'

describe ActiveTableSet::DatabaseServer do
  context "constructor" do
    it "raises on missing config" do
      expect { ActiveTableSet::DatabaseServer.new(server_type: :leader) }.to raise_error(ArgumentError, "missing keyword: config")
    end

    it "raises on missing server_type" do
      expect { ActiveTableSet::DatabaseServer.new(config: true) }.to raise_error(ArgumentError, "missing keyword: server_type")
    end
  end

  context "accessors" do
    let(:db_server) { ActiveTableSet::DatabaseServer.new(config: true, server_type: :leader) }

    it 'has a database connection type' do
      expect(db_server.server_type).to eq(:leader)
    end

    it 'has a database connection config' do
      expect(db_server.config).to eq(true)
    end
  end

  context "connections" do
    let(:db_server) { ActiveTableSet::DatabaseServer.new(config: true, server_type: :leader) }

    # TODO: figure out how to stub the calls to pool
    # connection is an AbstractAdapter (or object conforming to its interface)
  end
end
