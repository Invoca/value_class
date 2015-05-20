require 'spec_helper'

describe ActiveTableSet::DefaultConfigLoader do
  context "loading" do
    it "loads active table set config from YAML file" do
      loader = ActiveTableSet::DefaultConfigLoader.new
      config = loader.ats_configuration
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

    it "gives the common config as the current env config for ActiveRecord" do
      loader = ActiveTableSet::DefaultConfigLoader.new
      config = loader.ats_configuration[:table_sets][:common][:partitions][0][:leader]
      ar_config = loader.ar_configuration
      key = loader.ats_env
      expect(ar_config[key].is_a?(Hash)).to eq(true)
      expect(config[:username]).to eq(ar_config[key][:username])
      expect(config[:password]).to eq(ar_config[key][:password])
      expect(config[:host]).to eq(ar_config[key][:host])
      expect(config[:name]).to eq(ar_config[key][:name])
      expect(config[:timeout]).to eq(ar_config[key][:timeout])
    end
  end
end
