require 'spec_helper'

describe ActiveTableSet::Railties::EnableActiveTableSet do
  context "Railties" do

    it "defines an initializer" do
      initializers = ActiveTableSet::Railties::EnableActiveTableSet.initializers
      expect(initializers.count).to eq(1)
      expect(initializers.first.name).to eq("active_record.initialize_active_table_set")
    end

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
end
