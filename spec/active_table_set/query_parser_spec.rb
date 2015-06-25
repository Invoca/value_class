require 'spec_helper'

describe ActiveTableSet::QueryParser do
  context "query_parser" do
    context "selects" do
      {
        advertiser_select:         ["advertisers"],
        telco_select:              ["telco.lerg_melissa_prefixes", "telco.states", "telco.melissa_counties"],
        detail_report_select:      ["cf_advertiser_campaign_date_aggregate_pts", "cf_advertiser_campaign_dimensions"],
        detail_report_inner_query: ["cf_call_facts_20080101", "cf_virtual_line_dimensions", "cf_affiliate_dimensions", "cf_order_detail_dimensions"],
        number_pool_select:        ["calls", "number_pools"],
        billing_select:            ["advertisers", "invoice_line_item_details", "cf_advertiser_dimensions"]
      }.each do |query_file, expected_reads|
        it "parses #{query_file}" do
          qp = ActiveTableSet::QueryParser.new(load_sample_query(query_file))

          expect(qp.operation).to eq(:select)
          expect(qp.read_tables).to eq(expected_reads)
          expect(qp.write_tables).to eq([])
        end
      end
    end

    context "inserts" do
      {
          call_insert:               [["calls"],[]],
          warehouse_aggregate_insert:[["cf_advertiser_affiliate_date_aggregate_utcs"],[]],
          warehouse_fact_insert:     [["cf_call_facts_20110715"],[]],
      }.each do |query_file, values|

        it "parses #{query_file}" do
          write_tables, read_tables = values
          qp = ActiveTableSet::QueryParser.new(load_sample_query(query_file))

          expect(qp.operation).to eq(:insert)
          expect(qp.read_tables).to eq(read_tables)
          expect(qp.write_tables).to eq(write_tables)
        end
      end
    end

    context "updates" do
      {
          warehouse_aggregate_update:[["cf_advertiser_affiliate_date_aggregate_ets"],[]],
          warehouse_dimension_update:[["cf_virtual_line_dimensions"],[]],
          warehouse_fact_update:     [["cf_call_facts_20080101"],[]],
          multi_table_update:        [["advertiser_affiliate_joins"],["affiliates"]],
      }.each do |query_file, values|

        it "parses #{query_file}" do
          write_tables, read_tables = values
          qp = ActiveTableSet::QueryParser.new(load_sample_query(query_file))

          expect(qp.operation).to eq(:update)
          expect(qp.read_tables).to eq(read_tables)
          expect(qp.write_tables).to eq(write_tables)
        end
      end
    end


    context "deletes" do
      {
          simple_delete: [["pending_warehouse_imports"],[]],
          join_delete:   [["advertiser_campaigns"],["advertisers"]],
      }.each do |query_file, values|

        it "parses #{query_file}" do
          write_tables, read_tables = values
          qp = ActiveTableSet::QueryParser.new(load_sample_query(query_file))

          expect(qp.operation).to eq(:delete)
          expect(qp.read_tables).to eq(read_tables)
          expect(qp.write_tables).to eq(write_tables)
        end
      end
    end

    context "drop" do
      {
        table_drop: [["cf_rep_advertiser_campaigns_update_recent_call_counts_2s"],[]]
      }.each do |query_file, values|

        it "parses #{query_file}" do
          write_tables, read_tables = values
          qp = ActiveTableSet::QueryParser.new(load_sample_query(query_file))

          expect(qp.operation).to eq(:drop)
          expect(qp.read_tables).to eq(read_tables)
          expect(qp.write_tables).to eq(write_tables)
        end
      end
    end

    context "create_table" do
      {
        create_table: [["access_tokens"],[]]
      }.each do |query_file, values|

        it "parses #{query_file}" do
          write_tables, read_tables = values
          qp = ActiveTableSet::QueryParser.new(load_sample_query(query_file))

          expect(qp.operation).to eq(:create)
          expect(qp.read_tables).to eq(read_tables)
          expect(qp.write_tables).to eq(write_tables)
        end
      end
    end


    context "other sql commands" do
      [
          'SAVEPOINT active_record_1',
          'RELEASE SAVEPOINT active_record_1',
          'BEGIN',
          'COMMIT',
          'ROLLBACK',
          'SHOW FULL FIELDS FROM `outbound_integration_costs`',
          'SHOW TABLES LIKE'
      ].each do |command|
        it "parse misc sql command #{command}" do
          qp = ActiveTableSet::QueryParser.new(command)

          expect(qp.operation).to eq(:other)
          expect(qp.read_tables).to eq([])
          expect(qp.write_tables).to eq([])
        end
      end
    end

    it "should raise for unexpected queries" do
     expect { ActiveTableSet::QueryParser.new("not a sql command") }.to raise_error(RuntimeError, "unexpected query: not a sql command" )
    end
  end
end
