# frozen_string_literal: true

require 'spec_helper'

describe ActiveTableSet::Extensions::Mysql2AdapterOverride do
  context "Mysql2AdapterOverride" do
    before :each do
      small_table_set

      @connection = StubDbAdaptor.stub_db_connection()
      @connection.extend(ActiveTableSet::Extensions::Mysql2AdapterOverride)
    end

    it "responds to attr reader config" do
      expect(@connection).to respond_to(:config)
    end

    # all other methods for Mysql2AdapterOverride are implemented for 'non_nil_connection' and this is tested within abstract_adapter_override_spec.rb
  end
end
