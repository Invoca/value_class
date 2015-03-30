require 'spec_helper'

describe ActiveTableSet::ModelComparison do
  class Comparee
    include ActiveTableSet::ModelComparison
    attr_accessor :value1, :value2, :value3

    def initialize(value1: 1, value2: 2, value3: 3)
      @value1 = value1
      @value2 = value2
      @value3 = value3
    end
  end

  context "comparison" do
    it "provides an == operator" do
      c1 = Comparee.new
      c2 = Comparee.new
      expect(c1 == c2).to eq(true)

      c1.value1 = 4
      expect(c1 == c2).to eq(false)

      c1.value1 = 1
      c1.value2 = 5
      expect(c1 == c2).to eq(false)

      c1.value2 = 2
      c1.value3 = 6
      expect(c1 == c2).to eq(false)
    end

    it "provides an eql? operator" do
      c1 = Comparee.new
      c2 = Comparee.new
      expect(c1.eql?(c2)).to eq(true)

      c1.value1 = 4
      expect(c1.eql?(c2)).to eq(false)

      c1.value1 = 1
      c1.value2 = 5
      expect(c1.eql?(c2)).to eq(false)

      c1.value2 = 2
      c1.value3 = 6
      expect(c1.eql?(c2)).to eq(false)
    end

    it "tracks attributes declared on the class" do
      expect(Comparee.attributes[0]).to eq(:value1)
      expect(Comparee.attributes[1]).to eq(:value2)
      expect(Comparee.attributes[2]).to eq(:value3)
    end

    it "provides an instance method to access the class attributes" do
      c1 = Comparee.new
      expect(c1.attributes[0]).to eq(:value1)
      expect(c1.attributes[1]).to eq(:value2)
      expect(c1.attributes[2]).to eq(:value3)
    end
  end
end

