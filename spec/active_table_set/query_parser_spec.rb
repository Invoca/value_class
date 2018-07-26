# frozen_string_literal: true

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
          insert_ignore:             [["cf_advertiser_date_aggregate_pts"], ["cf_advertiser_date_aggregate_pt_repairs"]]
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

    context "truncate_table" do
      {
        truncate_table: [["cf_advertiser_date_aggregate_pt_repairs"],[]]
      }.each do |query_file, values|

        it "parses #{query_file}" do
          write_tables, read_tables = values
          qp = ActiveTableSet::QueryParser.new(load_sample_query(query_file))

          expect(qp.operation).to eq(:truncate)
          expect(qp.read_tables).to eq(read_tables)
          expect(qp.write_tables).to eq(write_tables)
        end
      end
    end

    context "queries with comments" do
      {
        leading_comment_large_query: ["cf_advertiser_campaign_date_aggregate_pts", "cf_advertiser_campaign_dimensions"]
      }.each do |query_file, expected_reads|

        it "parses #{query_file}" do
          qp = ActiveTableSet::QueryParser.new(load_sample_query(query_file))

          expect(qp.operation).to eq(:select)
          expect(qp.read_tables).to eq(expected_reads)
          expect(qp.write_tables).to eq([])
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
          'SET SQL_AUTO_IS_NULL=0, NAMES \'utf8\', @@wait_timeout = 2147483',
          'SHOW TABLES LIKE',
          'alter table access_tokens auto_increment = 1'
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
     expect { ActiveTableSet::QueryParser.new("not a sql command") }.to raise_error(RuntimeError, "ActiveTableSet::QueryParser.parse_query - unexpected query: not a sql command" )
    end

    it "should handle queries that contain binary data" do
      query = "          INSERT INTO simple_sessions ( session_id, marshaled_data, created_at, updated_at )\n          VALUES (\n            '346fb84574b37af67efce6034b3d7365',\n            '\u0004\b{\vI\\\"\u0010last_access\u0006:\u0006ETl+\aUC\x8FUI\\\"\u0010login_check\u0006;\\0Tl+\aUC\x8FUI\\\"\fuser_id\u0006;\\0Ti\u0006I\\\"\u0010username_id\u0006;\\0Ti\u0006I\\\"\u001Forganization_membership_id\u0006;\\0Ti\u0006I\\\"\u0015preferred_domain\u0006;\\0TI\\\"\u0017notvalidinvoca.net\u0006;\\0T',\n            '2015-06-28 00:44:06',\n            '2015-06-28 00:44:06'\n          )\n"
      qp = ActiveTableSet::QueryParser.new(query)
      expect(qp.operation).to eq(:insert)
      expect(qp.write_tables).to eq(['simple_sessions'])
      expect(qp.read_tables).to eq([])
    end

    it "handles this query" do
      query = "update cf_affiliate_dimensions
               set affiliate_global_name = 'aff five (Network 1)', affiliate_name = 'aff five'
               where affiliate_id = 5"

      qp = ActiveTableSet::QueryParser.new(query)
      expect(qp.operation).to eq(:update)
      expect(qp.read_tables).to eq([])
      expect(qp.write_tables).to eq(["cf_affiliate_dimensions"])
    end

  end
end
