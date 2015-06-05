require 'value_class'

module ValueClassSpec
  class Automobile
    attr_accessor :wheels, :doors

    def initialize(options)
      @wheels = options[:wheels]
      @doors = options[:doors]
    end

    def to_hash
      { "wheels" => @wheels, "doors" => @doors }
    end
  end
end

describe ValueClass::Attribute do
  context "attribute" do
    it "can be constructed from options" do
      attr = ValueClass::Attribute.new(:testAttr, description: "some description")

      expect(attr.name).to eq(:testAttr)
    end

    it "casts names to symbols" do
      attr = ValueClass::Attribute.new("testAttr", description: "some description")

      expect(attr.name).to eq(:testAttr)
    end

    it "does not allow arbitrary parameters" do
      @ex = nil
      begin
        ValueClass::Attribute.new("testAttr", not_a_valid_parameter: "boom baby")
      rescue => ex
        @ex = ex
      end

      expect(ex.class).to eq(ArgumentError)

      expect(ex.message).to eq("Unknown option(s): not_a_valid_parameter")
    end

    it "can have a description" do
      attr = ValueClass::Attribute.new("testAttr", description: "some description")
      expect(attr.name).to eq(:testAttr)

      expect(attr.description("     ")).to eq("     testAttr: some description")
    end

    it "can provide default for types that do not support dup" do
      attr = ValueClass::Attribute.new("testAttr", default: 5)

      expect(attr.default).to eq(5)
    end

    it "can provide default for types that support dup" do
      attr = ValueClass::Attribute.new("testAttr", default: { cat: "felix" })

      expect(attr.default).to eq(cat: "felix")
    end

    it "can have a limit" do
      attr = ValueClass::Attribute.new("testAttr", limit: ["cat", "dog", "bird"])
      expect(attr.limit).to eq(["cat", "dog", "bird"])
    end

    context "get_value" do
      it "reads from a hash" do
        attr = ValueClass::Attribute.new(:testAttr, {})
        expect(attr.get_value(testAttr: "found it!")).to eq("found it!")
      end

      it "reads from a method on the passed in class" do
        attr = ValueClass::Attribute.new(:testAttr, {})
        expect(attr.get_value(testAttr: "found it!")).to eq("found it!")
      end

      it "knows the difference between false and nil when assigning" do
        attr = ValueClass::Attribute.new(:testAttr, default: "this is not what I wanted")
        expect(attr.get_value(testAttr: false)).to eq(false)
      end

      context "typed attributes" do
        it "casts the passed in value to the type if a class is specified" do
          attr = ValueClass::Attribute.new(:testAttr, class_name: "ValueClassSpec::Automobile")

          value = attr.get_value(testAttr: { wheels: 4, doors: 2 })

          expect(value.class).to eq(ValueClassSpec::Automobile)
          expect(value.wheels).to eq(4)
          expect(value.doors).to eq(2)
        end

        it "casts the passed in value to the type if a class is specified" do
          attr = ValueClass::Attribute.new(:testAttr, list_of_class: "ValueClassSpec::Automobile")

          value = attr.get_value(testAttr: [{ wheels: 4, doors: 2 }, { wheels: 18, doors: 2 }])

          expect(value.first.class).to eq(ValueClassSpec::Automobile)
          expect(value.first.wheels).to eq(4)
          expect(value.first.doors).to eq(2)

          expect(value.last.wheels).to eq(18)
          expect(value.last.doors).to eq(2)
        end
      end

      context "limit" do
        it "allows values that match the limit" do
          attr = ValueClass::Attribute.new(:testAttr, limit: ["cat", "dog", "bird"])
          value = attr.get_value(testAttr: "cat")
          expect(value).to eq("cat")
        end

        it "raises argument error if the value does not match" do
          attr = ValueClass::Attribute.new(:testAttr, limit: ["cat", "dog", "bird"])
          expect { attr.get_value(testAttr: "mouse") }.to raise_error(ArgumentError, 'invalid value "mouse" for testAttr. allowed values ["cat", "dog", "bird"]')
        end
      end
    end

    context "hash_value" do
      it "passes along the value" do
        attr = ValueClass::Attribute.new(:testAttr, {})
        expect(attr.hash_value("found it!")).to eq("found it!")
      end

      it "returns a hash from a typed value" do
        attr = ValueClass::Attribute.new(:testAttr, class_name: "ValueClassSpec::Automobile")

        auto = ValueClassSpec::Automobile.new(wheels: 4, doors: 2)
        expect(attr.hash_value(auto)).to eq("wheels" => 4, "doors" => 2)
      end
    end
  end
end
