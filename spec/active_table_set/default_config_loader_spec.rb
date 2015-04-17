require 'spec_helper'

describe ActiveTableSet::DefaultConfigLoader do
  context "loading" do
    it "loads from YAML file" do
      loader = ActiveTableSet::DefaultConfigLoader.new
      config = loader.configuration
      expect(config[:table_sets].is_a?(Hash)).to eq(true)
      expect(config[:table_sets].count).to eq(2)
      common = config[:table_sets][:common]
      expect(common[:partitions].is_a?(Array)).to eq(true)
      expect(common[:partitions].count).to eq(1)
      partition = common[:partitions][0]
      expect(partition[:leader][:host]).to eq("127.0.0.8")
      expect(partition[:followers].count).to eq(0)
      expect(common[:readable].count).to eq(2)
      expect(common[:writable].count).to eq(2)
    end
  end
end
