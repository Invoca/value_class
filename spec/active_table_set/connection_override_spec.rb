require 'spec_helper'

describe ActiveTableSet::ConnectionOverride do
  context "AREL injection" do

    class TestDummy
      include ActiveRecord
      include ActiveTableSet::ConnectionOverride
    end

    it "overloads ActiveRecord::Base.connection to return a ConnectionProxy" do
      connection = TestDummy.connection
      expect(connection.is_a?(ActiveTableSet::ConnectionProxy)).to eq(true)
    end
  end
end
