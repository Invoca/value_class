require 'spec_helper'

describe ActiveTableSet::ConfigHelpers do
  class TestLoader
    include ActiveTableSet::ConfigHelpers
  end

  it "provides a localhost shortcut" do
    expect(TestLoader.new.local).to eq("localhost")
  end

  it "loads a YAML file" do
    ats_config_file = "#{File.dirname(__FILE__)}/../../config/active_table_set.yml"
    loader = TestLoader.new
    config = loader.load_yaml_config(ats_config_file)
    expect(config.is_a?(Hash)).to eq(true)
  end

  it "creates a database configuration hash appropriate for ActiveRecord" do
    loader = TestLoader.new
    config = loader.db_cfg(host: "myhost", username: "user", password: "pwd", name: "testdb", timeout: 300)

    expect(config.is_a?(Hash)).to eq(true)
    expect(config[:username]).to eq("user")
    expect(config[:password]).to eq("pwd")
    expect(config[:host]).to eq("myhost")
    expect(config[:database]).to eq("testdb")
    expect(config[:timeout]).to eq(300)
    expect(config[:collation]).to eq("utf8_general_ci")
  end
end
