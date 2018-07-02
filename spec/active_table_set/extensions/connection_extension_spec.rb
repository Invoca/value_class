# frozen_string_literal: true

require 'spec_helper'

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
end
