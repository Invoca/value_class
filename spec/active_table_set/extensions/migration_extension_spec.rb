# frozen_string_literal: true

require 'spec_helper'

class StubMigration
  attr_accessor :migrate_called, :migrate_direction

  def migrate(direction)
    @migrate_called    = true
    @migrate_direction = direction
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

    @stub_migration.migrate(:up)

    expect(@stub_migration.migrate_called).to eq(true)
    expect(@stub_migration.migrate_direction).to eq(:up)
  end

  it "configures the database on a down transition" do
    @stub_config = StubConfiguration.new
    @stub_migration = StubMigration.new

    expect(ActiveTableSet).to receive(:configuration) { @stub_config }

    expect(ActiveTableSet).to receive(:using).with(timeout: 50).and_yield

    @stub_migration.migrate(:down)

    expect(@stub_migration.migrate_called).to eq(true)
    expect(@stub_migration.migrate_direction).to eq(:down)
  end
end
