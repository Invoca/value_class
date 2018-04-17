require 'spec_helper'

describe ActiveTableSet::Configuration::TestScenario do
  let(:ip)       { "127.0.0.1" }
  let(:username) { "test_user" }
  let(:password) { "test_password" }
  let(:timeout)  { 5 }

  context "allows construction" do
    it "can be constructed" do
      test_scenario = ActiveTableSet::Configuration::TestScenario.new(scenario_name: 'main', host: ip, timeout: 40)

      expect(test_scenario.scenario_name).to eq('main')
      expect(test_scenario.timeout).to       eq(40)
    end
  end

  context "connection_spec" do
    it "generates a connection specification " do
      prev_request = ActiveTableSet::Configuration::Request.new(
        table_set: :common,
        access: :leader,
        partition_key: nil,
        test_scenario: nil,
        timeout: 100 )

      prev_con_attributes = large_table_set.connection_attributes(prev_request)

      test_scenario = large_table_set.test_scenarios.first

      request = ActiveTableSet::Configuration::Request.new(table_set: :foo, access: :leader, timeout: 100, test_scenario: test_scenario.scenario_name)

      con_attributes = test_scenario.connection_attributes(request, [], "foo", prev_con_attributes)

      expect(con_attributes.pool_key.host).to eq(test_scenario.host)
      expect(con_attributes.pool_key.username).to eq(test_scenario.read_write_username)
    end
  end
end
