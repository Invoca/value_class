require 'value_class'

describe ValueClass::Attribute do
  context "attribute" do

    it "can be constructed from options" do
      attr = ValueClass::Attribute.new("testAttr", description: "some description")

      expect(attr.name).to eq("testAttr")
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
      expect(attr.name).to eq("testAttr")

      expect(attr.description("     ")).to eq("     testAttr: some description")
    end

    it "can provide default for types that do not support dup" do
      attr = ValueClass::Attribute.new("testAttr", default: 5)

      expect(attr.default).to eq(5)
    end

    it "can provide default for types that support dup" do
      attr = ValueClass::Attribute.new("testAttr", default: {cat: "felix"})

      expect(attr.default).to eq(cat: "felix")
    end

  end
end
