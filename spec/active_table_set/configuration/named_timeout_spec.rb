# frozen_string_literal: true

require 'spec_helper'

describe ActiveTableSet::Configuration::NamedTimeout do
  context "named_timeout" do
    subject(:named_timeout) { ActiveTableSet::Configuration::NamedTimeout.new(name: name, timeout: timeout, net_read_timeout: net_read_timeout, net_write_timeout: net_write_timeout) }
    let(:name) { :web }
    let(:timeout) { 110.seconds }
    let(:net_read_timeout) { 10.minutes }
    let(:net_write_timeout) { 5.minutes }

    it "can be constructed" do
      expect(named_timeout.name).to eq(:web)
      expect(named_timeout.timeout).to eq(110)
      expect(named_timeout.net_read_timeout).to eq(600)
      expect(named_timeout.net_write_timeout).to eq(300)
    end

    describe "name" do
      let(:name) { nil }

      it "is required" do
        expect { named_timeout }.to raise_error(ArgumentError, "must provide a value for name")
      end
    end

    describe "timeout" do
      let(:timeout) { nil }

      it "is required" do
        expect { named_timeout }.to raise_error(ArgumentError, "must provide a value for timeout")
      end
    end

    describe "net_read_timeout" do
      let(:net_read_timeout) { nil }

      it "is optional" do
        expect(named_timeout.net_read_timeout).to be_nil
      end
    end

    describe "net_write_timeout" do
      let(:net_write_timeout) { nil }

      it "is optional" do
        expect(named_timeout.net_write_timeout).to be_nil
      end
    end

    describe "timeout_hash" do
      let(:timeout) { 10.minutes }
      let(:net_read_timeout) { 5.minutes }
      let(:net_write_timeout) { 1.minute }

      it "returns a symbolized hash of timeout variables" do
        expected_hash = {
          timeout: 10.minutes,
          net_read_timeout: 5.minutes,
          net_write_timeout: 1.minute
        }

        expect(named_timeout.timeout_hash).to eq(expected_hash)
      end
    end
  end
end

