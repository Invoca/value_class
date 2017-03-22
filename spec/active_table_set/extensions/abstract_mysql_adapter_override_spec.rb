require 'spec_helper'

describe ActiveTableSet::Extensions::AbstractMysqlAdapterOverride do
  context "Mysql2AdapterOverride" do
    before :each do
      small_table_set

      @connection = StubDbAdaptor.stub_db_connection()
      @connection.extend(ActiveTableSet::Extensions::AbstractMysqlAdapterOverride)
    end

    # all other methods for Mysql2AdapterOverride are implemented for 'non_nil_connection' and this is tested within abstract_adapter_override_spec.rb
  end
end
