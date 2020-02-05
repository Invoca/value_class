# frozen_string_literal: true

require 'spec_helper'

describe ActiveTableSet::Configuration::Request do
  context "default" do
    it "can be constructed" do
      dc = ActiveTableSet::Configuration::Request.new(table_set: :common)

      expect(dc.table_set).to eq(:common)
    end

    context "access" do
      subject { ActiveTableSet::Configuration::Request.new(table_set: :common, access: :balanced) }

      it "respects an override when set through process settings" do
        expect(subject.table_set).to eq(:common)
        expect(subject.access).to eq(:balanced)

        replace_process_settings_with_fixture(:combined_process_settings_global)

        expect(subject.access).to eq(:leader)

        replace_process_settings_with_fixture(:combined_process_settings_empty)

        expect(subject.access).to eq(:balanced)
      end
    end

    context "merge" do
      it "allows requests to be merged" do
        orig = ActiveTableSet::Configuration::Request.new(
          table_set: :common,
          access: :leader,
          partition_key: nil,
          timeout: 10,
          net_read_timeout: 100,
          net_write_timeout: 60,
          test_scenario: nil
        )

        replacement = ActiveTableSet::Configuration::Request.new(
          timeout: 110,
          net_read_timeout: 600,
          net_write_timeout: 300,
        )

        merged = orig.merge(replacement)

        expect(merged.table_set).to eq(:common)
        expect(merged.access).to eq(:leader)
        expect(merged.partition_key).to eq(nil)
        expect(merged.timeout).to eq(110)
        expect(merged.net_read_timeout).to eq(600)
        expect(merged.net_write_timeout).to eq(300)
        expect(merged.test_scenario).to eq(nil)
      end

      it "clears the partition key if the table set changes" do
        orig = ActiveTableSet::Configuration::Request.new(
          table_set: :sharded,
          access: :leader,
          partition_key: "alpha",
          timeout: 10,
          test_scenario: nil
        )

        replacement = ActiveTableSet::Configuration::Request.new(
          table_set: :common
        )

        merged = orig.merge(replacement)

        expect(merged.table_set).to eq(:common)
        expect(merged.access).to eq(:leader)
        expect(merged.partition_key).to eq(nil)
        expect(merged.timeout).to eq(10)
        expect(merged.test_scenario).to eq(nil)
      end

      it "allows a hash to be passed instead of an instance" do
        orig = ActiveTableSet::Configuration::Request.new(
          table_set: :common,
          access: :leader,
          partition_key: nil,
          timeout: 10,
          test_scenario: nil
        )

        merged = orig.merge(timeout: 110, net_read_timeout: 600)

        expect(merged.table_set).to eq(:common)
        expect(merged.access).to eq(:leader)
        expect(merged.partition_key).to eq(nil)
        expect(merged.timeout).to eq(110)
        expect(merged.net_read_timeout).to eq(600)
        expect(merged.net_write_timeout).to eq(nil)
        expect(merged.test_scenario).to eq(nil)
      end

      it "merges with a partition key" do
        orig = ActiveTableSet::Configuration::Request.new(
          table_set: :common,
          access: :leader,
          partition_key: "2",
          timeout: 10,
          test_scenario: nil
        )

        merged = orig.merge(timeout: 110)

        expect(merged.table_set).to eq(:common)
        expect(merged.access).to eq(:leader)
        expect(merged.partition_key).to eq("2")
        expect(merged.timeout).to eq(110)
        expect(merged.test_scenario).to eq(nil)
      end
    end
  end
end

