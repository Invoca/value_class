require 'spec_helper'

describe ActiveTableSet::PoolKey do
  context "pool key" do

    it "is constructable and comparible" do
      pk  = ActiveTableSet::PoolKey.new(host: "localhost")
      pk2 = ActiveTableSet::PoolKey.new(host: "somewhere else")
      pk3 = ActiveTableSet::PoolKey.new(host: "localhost")

      expect(pk).to eq(pk3)
      expect(pk).not_to eq(pk2)
    end

    it "generates a name based on the connection spec" do
      pk = ActiveTableSet::PoolKey.new(adapter: "sqlite")
      expect(pk.connector_name).to eq("sqlite_connection")
    end

    it "generates a connection spec" do
      pk = ActiveTableSet::PoolKey.new(adapter: "sqlite")
      spec = pk.connection_spec
      expect(spec.config).to eq(pk.to_hash)
      expect(spec.adapter_method).to eq(pk.connector_name)
    end
  end
end

