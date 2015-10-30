require 'spec_helper'

module ConnectionExtensionSpec
  class TestInstanceDelegation
    include ActiveTableSet::Extensions::ConnectionExtension
  end

  class TestClassDelegation
    extend ActiveTableSet::Extensions::ConnectionExtension
  end
end

describe ActiveTableSet::Extensions::ConnectionExtension do
  context "log checking" do
    it "adds the host to the log message" do
      class TestExtensionLogging
        prepend ActiveTableSet::Extensions::ConnectionExtension

        def initialize(config)
          @config = config
        end

        def config
          @config
        end

        def log(sql, name, binds)
          return name
        end
      end

      test_log = TestExtensionLogging.new({})
      expect(test_log.log('', '')).to match(/host:/)
    end
  end
  context "ConvientDelegation" do

    it "can delegate using to instances" do
      inst = ConnectionExtensionSpec::TestInstanceDelegation.new

      @called_block = false
      expect(ActiveTableSet).to receive(:using).with(table_set: :ts, access: :am, partition_key: :pk, timeout: :t).and_yield
      inst.using(table_set: :ts, access: :am, partition_key: :pk, timeout: :t) do
        @called_block = true
      end

      expect(@called_block).to eq(true)
    end

    it "can delegate using to classes" do
      @called_block = false
      expect(ActiveTableSet).to receive(:using).with(table_set: :ts, access: :am, partition_key: :pk, timeout: :t).and_yield
      ConnectionExtensionSpec::TestClassDelegation.using(table_set: :ts, access: :am, partition_key: :pk, timeout: :t) do
        @called_block = true
      end

      expect(@called_block).to eq(true)
    end

    it "delegates the lock_access method" do
      @called_block = false
      expect(ActiveTableSet).to receive(:lock_access).with(:leader).and_yield

      ConnectionExtensionSpec::TestClassDelegation.lock_access(:leader) do
        @called_block = true
      end

      expect(@called_block).to eq(true)
    end
  end
end
