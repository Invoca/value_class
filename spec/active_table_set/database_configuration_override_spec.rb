require 'spec_helper'

describe ActiveTableSet::DatabaseConfigurationOverride do
  context "Rails injection" do

    class DbTestDummy
      include ActiveTableSet::DatabaseConfigurationOverride
    end

    it "overloads ActiveRecord::Base.configuration to return a programatically constructed hash" do
      config = DbTestDummy.new
      expect(config.database_configuration[:test].is_a?(Hash)).to eq(true)
    end
  end
end
