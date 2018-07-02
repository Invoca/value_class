# frozen_string_literal: true

require 'spec_helper'

describe ActiveTableSet::Configuration::NamedTimeout do
  context "named_timeout" do

    it "can be constructed" do
      nt = ActiveTableSet::Configuration::NamedTimeout.new(name: :web, timeout: 110.seconds)
      expect(nt.name).to eq(:web)
      expect(nt.timeout).to eq(110)
    end

    it "requires arguments" do
      expect { ActiveTableSet::Configuration::NamedTimeout.new(timeout: 1) }.to raise_error(ArgumentError, "must provide a value for name")
      expect { ActiveTableSet::Configuration::NamedTimeout.new(name: :web) }.to raise_error(ArgumentError, "must provide a value for timeout")
    end

  end
end

