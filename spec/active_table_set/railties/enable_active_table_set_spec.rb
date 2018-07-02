# frozen_string_literal: true

require 'spec_helper'

describe ActiveTableSet::Railties::EnableActiveTableSet do
  context "Railties" do

    it "defines an initializer" do
      initializers = ActiveTableSet::Railties::EnableActiveTableSet.initializers
      expect(initializers.count).to eq(2)
      expect(initializers.first.name).to eq("active_record.initialize_active_table_set")
      expect(initializers.last.name).to eq("active_table_set.test_database")
    end

    context "active_record.initialize_active_table_set" do
      it "enables active table set if configured" do
        expect(ActiveTableSet).to receive(:configured?) { true }
        expect(ActiveTableSet).to receive(:enable)

        ActiveTableSet::Railties::EnableActiveTableSet.initializers.first.run
      end

      it "does not enable active table set if not configured" do
        expect(ActiveTableSet).to receive(:configured?) { false }
        expect(ActiveTableSet).to receive(:enable).never

        ActiveTableSet::Railties::EnableActiveTableSet.initializers.first.run
      end
    end

    context "active_table_set.test_database" do
      it "sets the test scenario if configured" do
        expect(ActiveTableSet).to receive(:configured?) { true }
        dbl = double("config")

        expect(ActiveTableSet).to receive(:configuration).twice { dbl }
        expect(dbl).to receive(:default_test_scenario).twice { "kittens" }

        expect(ActiveTableSet).to receive(:use_test_scenario).with("kittens")

        ActiveTableSet::Railties::EnableActiveTableSet.initializers.last.run
      end

      it "does not set the scenario if not configured" do
        expect(ActiveTableSet).to receive(:configured?) { false }
        expect(ActiveTableSet).to receive(:configuration).never
        expect(ActiveTableSet).to receive(:use_test_scenario).never

        ActiveTableSet::Railties::EnableActiveTableSet.initializers.last.run
      end

      it "does not set the scenario if no scenario selected" do
        expect(ActiveTableSet).to receive(:configured?) { true }

        dbl = double("config")

        expect(ActiveTableSet).to receive(:configuration) { dbl }
        expect(dbl).to receive(:default_test_scenario) {  }

        expect(ActiveTableSet).to receive(:use_test_scenario).never

        ActiveTableSet::Railties::EnableActiveTableSet.initializers.last.run
      end

    end

  end
end
