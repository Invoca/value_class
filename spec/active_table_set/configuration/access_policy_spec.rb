require 'spec_helper'

describe ActiveTableSet::Configuration::AccessPolicy do
  context "access_policy" do

    it "allows access by default" do
      ap = ActiveTableSet::Configuration::AccessPolicy.new

      expect(ap.errors(write_tables: ["advertiser_campaigns"], read_tables: ["advertisers"])).to eq([])
    end

    it "should allow access to be blocked by disallowing it" do
      ap = ActiveTableSet::Configuration::AccessPolicy.new(disallow_read: 'advertisers')

      expected = ['Cannot read advertisers']
      expect(ap.errors(write_tables: [], read_tables: ["advertisers"])).to eq(expected)
    end

    it "should allow disallowed lists to support wildcards" do
      ap = ActiveTableSet::Configuration::AccessPolicy.new(disallow_read: 'adv%')

      expected = ['Cannot read advertisers']
      expect(ap.errors(write_tables: [], read_tables: ["advertisers"])).to eq(expected)

      expect(ap.errors(write_tables: [], read_tables: ["affiliates"])).to eq([])
    end

    it "should report multiple errors" do
      ap = ActiveTableSet::Configuration::AccessPolicy.new(disallow_read: 'adv%')

      expected = [
          'Cannot read advertisers',
          'Cannot read advertiser_campaigns',
      ]
      expect(ap.errors(write_tables: [], read_tables: ["advertisers", "advertiser_campaigns"])).to eq(expected)

      expect(ap.errors(write_tables: [], read_tables: ["affiliates"])).to eq([])
    end

    it "should allow multiple patterns" do
      ap = ActiveTableSet::Configuration::AccessPolicy.new(disallow_read: 'adv%,aff%')

      expect(ap.errors(write_tables: [], read_tables: ["advertisers"])).to eq(['Cannot read advertisers'])
      expect(ap.errors(write_tables: [], read_tables: ["affiliates"])).to eq(['Cannot read affiliates'])

      expect(ap.errors(write_tables: [], read_tables: ["users"])).to eq([])
    end

    it "should report read and write errors" do
      ap = ActiveTableSet::Configuration::AccessPolicy.new(disallow_read: 'adv%,aff%', disallow_write: 'adv%,aff%')

      expect(ap.errors(write_tables: [], read_tables: ["advertisers"])).to eq(['Cannot read advertisers'])
      expect(ap.errors(write_tables: ["affiliates"], read_tables: [])).to eq(['Cannot write affiliates'])

      expect(ap.errors(write_tables: ["users"], read_tables: ["users"])).to eq([])
    end

    it "should check allowed policies" do
      ap = ActiveTableSet::Configuration::AccessPolicy.new(allow_read: 'adv%,aff%', allow_write: 'adv%,aff%')

      expected = [
          'Cannot read users',
          'Cannot write users',
      ]
      expect(ap.errors(write_tables: ["users"], read_tables: ["users"])).to eq(expected)

      expect(ap.errors(write_tables: [], read_tables: ["advertisers"])).to eq([])
      expect(ap.errors(write_tables: ["affiliates"], read_tables: [])).to eq([])
    end

    it "should have a clean way of reporting its configuration" do
      ap = ActiveTableSet::Configuration::AccessPolicy.new(allow_read: 'adv%,aff%', disallow_read: 'advertiser_camp%', allow_write: 'adv%,aff%')

      expected = [
        "allow_read: adv%,aff%",
        "disallow_read: advertiser_camp%",
        "allow_write: adv%,aff%"
      ]

      expect(ap.access_rules).to eq(expected)
    end

  end
end

