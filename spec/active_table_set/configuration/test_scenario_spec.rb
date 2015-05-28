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
end
