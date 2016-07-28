require 'spec_helper'

describe ActiveTableSet::Extensions::Mysql2AdapterOverride do
  context "Mysql2AdapterOverride" do
    before :each do
      ActiveTableSet.config do |conf|
        conf.enforce_access_policy true
        conf.environment           'test'
        conf.default  =  { table_set: :common }

        conf.table_set do |ts|
          ts.name = :common

          ts.access_policy do |ap|
            ap.disallow_read  'cf_%'
            ap.disallow_write 'cf_%'
          end

          ts.partition do |part|
            part.leader do |leader|
              leader.host                 "10.0.0.1"
              leader.read_write_username  "tester"
              leader.read_write_password  "verysecure"
              leader.database             "main"
            end
          end
        end
      end

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
