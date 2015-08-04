require 'spec_helper'

class StubMigration
  attr_accessor :up_called, :down_called

  def up
    @up_called = true
  end

  def down
    @down_called = true
  end
end

StubMigration.prepend(ActiveTableSet::Extensions::MigrationExtension)

class StubConfiguration
  def migration_timeout
    50
  end
end

describe ActiveTableSet::Extensions::MigrationExtension do
  it "configures the database on an up transition" do
    @stub_config = StubConfiguration.new
    @stub_migration = StubMigration.new

    expect(ActiveTableSet).to receive(:configuration) { @stub_config }

    expect(ActiveTableSet).to receive(:using).with(timeout: 50).and_yield

    @stub_migration.up

    expect(@stub_migration.up_called).to eq(true)
  end

  it "configures the database on a down transition" do
    @stub_config = StubConfiguration.new
    @stub_migration = StubMigration.new

    expect(ActiveTableSet).to receive(:configuration) { @stub_config }

    expect(ActiveTableSet).to receive(:using).with(timeout: 50).and_yield

    @stub_migration.down

    expect(@stub_migration.down_called).to eq(true)
  end

  it "configures the database oon connection method" do
    @stub_config = StubConfiguration.new
    @stub_migration = StubMigration.new

    expect(ActiveTableSet).to receive(:configuration) { @stub_config }

    expect(ActiveTableSet).to receive(:using).with(timeout: 50).and_yield

    @stub_migration.down

    expect(@stub_migration.down_called).to eq(true)
  end
end
