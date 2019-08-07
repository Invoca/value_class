# frozen_string_literal: true

require 'spec_helper'

describe ActiveTableSet::Configuration::TestScenario do
  subject(:test_scenario) { ActiveTableSet::Configuration::TestScenario.new(scenario_name: scenario_name, host: ip, timeout: timeout, net_read_timeout: net_read_timeout) }
  let(:scenario_name) { "main" }
  let(:ip)       { "127.0.0.1" }
  let(:username) { "test_user" }
  let(:password) { "test_password" }
  let(:timeout)  { 5 }
  let(:net_read_timeout)  { 15 }

  context "allows construction" do
    it "can be constructed" do
      expect(test_scenario.scenario_name).to eq('main')
      expect(test_scenario.timeout).to eq(5)
      expect(test_scenario.net_read_timeout).to eq(15)
    end
  end

  context "connection_spec" do
    it "generates a connection specification " do
      prev_request = ActiveTableSet::Configuration::Request.new(
        table_set: :common,
        access: :leader,
        partition_key: nil,
        test_scenario: nil,
        timeout: 100)

      prev_con_attributes = large_table_set.connection_attributes(prev_request)

      test_scenario = large_table_set.test_scenarios.first

      request = ActiveTableSet::Configuration::Request.new(table_set: :foo, access: :leader, timeout: 100, test_scenario: test_scenario.scenario_name)

      con_attributes = test_scenario.connection_attributes(request, [], "foo", prev_con_attributes)

      expect(con_attributes.pool_key.host).to eq(test_scenario.host)
      expect(con_attributes.pool_key.username).to eq(test_scenario.read_write_username)
    end
  end
end
