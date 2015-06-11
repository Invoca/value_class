require 'spec_helper'

describe ActiveTableSet::Configuration::ClassTableSet do
  context "named_timeout" do

    it "can be constructed" do
      nt = ActiveTableSet::Configuration::ClassTableSet.new(class_name: "Advertiser", table_set: :common)
      expect(nt.class_name).to eq("Advertiser")
      expect(nt.table_set).to eq(:common)
    end

    it "requires arguments" do
      expect { ActiveTableSet::Configuration::ClassTableSet.new(class_name: 'foo') }.to raise_error(ArgumentError, "must provide a value for table_set")
      expect { ActiveTableSet::Configuration::ClassTableSet.new(table_set: :bar) }.to raise_error(ArgumentError, "must provide a value for class_name")
    end

  end
end

