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
      @connection.extend(ActiveTableSet::Extensions::Mysql2AdapterOverride)
    end

    it "responds to attr reader config" do
      expect(@connection).to respond_to(:config)
    end

    # all other methods for Mysql2AdapterOverride are implemented for 'non_nil_connection' and this is tested within abstract_adapter_override_spec.rb
  end
end
