require 'spec_helper'

describe ActiveTableSet::Configuration::UsingSpec do
  context "default_connection" do
    it "can be constructed" do
      dc = ActiveTableSet::Configuration::UsingSpec.new(table_set: :common)

      expect(dc.table_set).to   eq(:common)
      expect(dc.access_mode).to eq(:write)
    end

    it "raises if you do not specify a table set" do
      expect { ActiveTableSet::Configuration::UsingSpec.new({}) }.to raise_error(ArgumentError, "must provide a value for table_set")
    end
  end
end

