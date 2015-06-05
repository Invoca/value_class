require 'spec_helper'

class StubRailsApplication
  def database_configuration
    raise "Fail, this is not supposed to be called!"
  end
end

describe ActiveTableSet::Extensions::DatabaseConfigurationOverride do


  context "DatabaseConfigurationOverride" do
    it "overrides the database configuration method" do
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
              leader.host      "10.0.0.1"
              leader.read_write_username  "tester"
              leader.read_write_password  "verysecure"
              leader.database  "main"
            end
          end
        end
      end

      StubRailsApplication.send(:prepend, ActiveTableSet::Extensions::DatabaseConfigurationOverride)

      expect(ActiveTableSet).to receive(:database_configuration) { "configuration" }

      db_config = StubRailsApplication.new.database_configuration

      expect(db_config).to eq("configuration")
    end
  end
end
