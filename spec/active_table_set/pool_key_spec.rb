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
  end
end

