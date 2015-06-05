require 'spec_helper'

describe ActiveTableSet::Extensions::MysqlConnectionMonitor do
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
            leader.host      "10.0.0.1"
            leader.read_write_username  "tester"
            leader.read_write_password  "verysecure"
            leader.database  "main"
          end
        end
      end
    end

    ActiveTableSet.enable
  end

  context "connection monitor" do
    let(:no_advertisers) { ActiveTableSet::Configuration::AccessPolicy.new(disallow_read: 'adv%,aff%', disallow_write: 'adv%,aff%') }

    it "confirm you can monitor connections" do
      @connection = StubDbAdaptor.stub_db_connection()
      ActiveTableSet::Extensions::MysqlConnectionMonitor.install(@connection)

      expect(@connection.respond_to?(:access_policy)).to eq(true)
      @connection.access_policy = no_advertisers
    end

    it "does nothing if the access policy is empty" do
      @connection = StubDbAdaptor.stub_db_connection()
      ActiveTableSet::Extensions::MysqlConnectionMonitor.install(@connection)

      @connection.select_rows(load_sample_query(:multi_table_update))
    end

    it "does nothing if the query is allowed" do
      @connection = StubDbAdaptor.stub_db_connection()
      ActiveTableSet::Extensions::MysqlConnectionMonitor.install(@connection)

      @connection.access_policy = no_advertisers

      @connection.select_rows(load_sample_query(:number_pool_select))
    end


    it "reports useful error messages when an connection attempts to access " do
      @connection = StubDbAdaptor.stub_db_connection()
      ActiveTableSet::Extensions::MysqlConnectionMonitor.install(@connection)

      @connection.access_policy = no_advertisers

      begin
        @connection.select_rows(load_sample_query(:multi_table_update))
        fail 'did not raise an exception'
      rescue => ex
        expect(ex.class.name).to eq("ActiveTableSet::AccessNotAllowed")

        expected_message  = <<-EOF.gsub(/^ {10}/, '')
          Query denied by Active Table Set access_policy: (are you using the correct table set?)
          ==============================   access_policy    ==============================
          allow_read: %
          disallow_read: adv%,aff%
          allow_write: %
          disallow_write: adv%,aff%
          ================================================================================

          ==============================       errors       ==============================
          Cannot read affiliates
          Cannot write advertiser_affiliate_joins
          ================================================================================

          ==============================        query       ==============================
                   update advertiser_affiliate_joins
                     inner join affiliates on affiliates.id = advertiser_affiliate_joins.affiliate_id
                     set advertiser_affiliate_joins.status_update_from = 'API'
                     where affiliates.network_id = 1
          ================================================================================
        EOF

        expect(ex.message).to eq(expected_message)
      end
    end

  end
end

