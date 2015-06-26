require 'spec_helper'

describe ActiveTableSet::ConnectionAttributes do
  context "pool key" do

    it "is constructable and comparible" do
      pk  = ActiveTableSet::ConnectionAttributes.new(pool_key: "localhost")
      pk2 = ActiveTableSet::ConnectionAttributes.new(pool_key: "somewhere else")
      pk3 = ActiveTableSet::ConnectionAttributes.new(pool_key: "localhost")

      expect(pk).to eq(pk3)
      expect(pk).not_to eq(pk2)
    end
  end

  it "has an optional failover pool key" do
    pk  = ActiveTableSet::ConnectionAttributes.new(pool_key: "localhost", failover_pool_key: "notlocal")
    expect(pk.failover_pool_key).to eq("notlocal")
  end
end

