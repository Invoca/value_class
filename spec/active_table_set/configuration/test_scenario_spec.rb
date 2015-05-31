require 'spec_helper'

describe ActiveTableSet::Configuration::TestScenario do
  let(:ip)       { "127.0.0.1" }
  let(:username) { "test_user" }
  let(:password) { "test_password" }
  let(:timeout)  { 5 }
  context "allows construction" do
    it "can be constructed" do
      test_scenario = ActiveTableSet::Configuration::TestScenario.new(scenario_name: 'main', host: ip, username: username, password: password, timeout: timeout)

      expect(test_scenario.scenario_name).to eq('main')
    end
  end

  context "connection_spec" do
    it "generates a connection specification " do
      prev_request = ActiveTableSet::Configuration::Request.new(
        table_set: :common,
        access_mode: :write,
        partition_key: nil,
        test_scenario: nil,
        timeout: 100 )

      prev_con_spec = large_table_set.connection_spec(prev_request)

      test_scenario = large_table_set.test_scenarios.first

      request = ActiveTableSet::Configuration::Request.new(table_set: :foo, access_mode: :write, timeout: 100, test_scenario: test_scenario.scenario_name)

      con_spec = test_scenario.connection_spec(request, [], "foo", prev_con_spec)

      expect(con_spec.specification.host).to eq(test_scenario.host)
      expect(con_spec.specification.username).to eq(test_scenario.read_write_username)
    end
  end

end
