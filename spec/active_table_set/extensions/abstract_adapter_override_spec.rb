require 'spec_helper'

describe ActiveTableSet::Extensions::Mysql2AdapterOverride do
  context "Mysql2AdapterOverride" do
    before :each do
      small_table_set

      @connection = StubDbAdaptor.stub_db_connection()
      @connection.extend(ActiveTableSet::Extensions::AbstractAdapterOverride)
    end

    it "responds to reset_rows_read method" do
      expect(@connection).to respond_to(:reset_rows_read)
    end

    it "responds to connection= method" do
      expect(@connection).to receive(:connection=)
      @connection.send(:connection=)
    end

    it "responds to non_nil_connection method" do
      expect(@connection).to receive(:non_nil_connection)
      @connection.send(:non_nil_connection)
    end

    it "raises error if connection is not defined" do
      @connection.disconnect!

      begin
        @connection.send(:non_nil_connection)
        fail 'did not raise an exception'
      rescue => ex
        expect(ex.class.name).to eq("RuntimeError")
        expect(ex.message).to eq("Connection is nil! It was assigned by:\n<none>")
      end
    end
  end
end
