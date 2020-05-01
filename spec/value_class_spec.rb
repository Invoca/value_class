# frozen_string_literal: true

require 'value_class'

module ValueClassTest
  class BikeTire
    include ValueClass

    value_attr :diameter, description: "The diameter in inches"
    value_attr :tred,     description: "The tred on the tire"
  end

  class BikeSeat
    include ValueClass

    value_attr :size, description: "The size of the bike seat in inches"
    value_attr :color
  end

  class Bicycle
    include ValueClass

    value_description "For riding around town"
    value_attr :speeds
    value_attr :color, default: :orange
    value_attr :seat, class_name: 'ValueClassTest::BikeSeat'

    value_list_attr :riders
    value_list_attr :tires, class_name: 'ValueClassTest::BikeTire'
  end

  class Headlight
    include ValueClass
    value_attr :lumens, required: true
  end

  class HandleBar
    include ValueClass
    value_attrs :style, :grip, :brakes, :headlight, :bell
  end

  class Gears
    include ValueClass
    value_attrs :first_gear, :second_gear, :third_gear, default: 200
  end

  class MountainBicycle < Bicycle
    value_attr :shocks
  end

  class QuickGears < ValueClass.struct(:first_gear, :second_gear, :third_gear, default: 200)
  end

  QuickerGears = ValueClass.struct(:first_gear, :second_gear, :third_gear, default: 200)
end

describe ValueClass do
  context "configurable" do
    it "supports generating a description" do
      expected_description  = <<-EOF.gsub(/^ {8}/, '')
        ValueClassTest::Bicycle: For riding around town
          attributes:
            speeds
            color
            seat
            riders
            tires
      EOF

      expect(ValueClassTest::Bicycle.config_help).to eq(expected_description)
    end

    it "be able to construct the class with a hash" do
      bike = ValueClassTest::Bicycle.new(speeds: 10, color: :gold)
      expect(bike.color).to eq(:gold)
    end

    context "lists" do
      it "be able to construct the class with a hash" do
        bike = ValueClassTest::Bicycle.new(speeds: 10, color: :gold, tires: [{ diameter: 40, tred: :mountain }, { diameter: 50, tred: :slicks }])

        expect(bike.tires.map(&:diameter)).to eq([40, 50])
        expect(bike.tires.map(&:tred)).to eq([:mountain, :slicks])
      end
    end

    it "should freeze all attributes" do
      bike = ValueClassTest::Bicycle.new(speeds: 10, color: :gold, tires: [{ diameter: 40, tred: :mountain }, { diameter: 50, tred: :slicks }])

      expect(bike.speeds.frozen?).to      eq(true)
      expect(bike.color.frozen?).to       eq(true)
      expect(bike.tires.frozen?).to       eq(true)
      expect(bike.tires.first.frozen?).to eq(true)
    end

    it "should raise an exception if a required parameter is missing" do
      expect { ValueClassTest::Headlight.new }.to  raise_error(ArgumentError, "must provide a value for lumens")
    end

    it "should raise an exception if an unsupported parameter is passed" do
      expect { ValueClassTest::Headlight.new(unknown: nil) }.to  raise_error(ArgumentError, "unknown attribute unknown")
    end

    it "allow for quick declaration using default options" do
      handle_bar = ValueClassTest::HandleBar.new(style: :chopper, grip: :cork_tape, brakes: true, bell: false)

      expect(handle_bar.style).to eq(:chopper)
      expect(handle_bar.grip).to eq(:cork_tape)
      expect(handle_bar.brakes).to eq(true)
      expect(handle_bar.bell).to eq(false)
      expect(handle_bar.brakes).to eq(true)

      expect(handle_bar.headlight).to eq(nil)
    end

    it "allow for quick declaration while specifying options" do
      gear = ValueClassTest::Gears.new(first_gear: 20)

      expect(gear.first_gear).to eq(20)
      expect(gear.second_gear).to eq(200)
      expect(gear.third_gear).to eq(200)
    end

    context "comparison" do
      it "allows value types to be comparied" do
        gear      = ValueClassTest::Gears.new(first_gear: 20)
        gear_same = ValueClassTest::Gears.new(first_gear: 20)
        gear_diff = ValueClassTest::Gears.new(first_gear: 21)

        expect(gear).to     eq(gear_same)
        expect(gear).not_to eq(gear_diff)

        expect(gear).to     eql(gear_same)
        expect(gear).not_to eql(gear_diff)

        expect(gear.hash).to     eq(gear_same.hash)
        expect(gear.hash).not_to eq(gear_diff.hash)

        test_hash = { gear_same => "value1", gear_diff => "value2" }

        expect(test_hash[gear]).to eq("value1")
      end
    end

    context "to_hash" do
      it "allows creation of a hash from the instance" do
        bike = ValueClassTest::MountainBicycle.new(speeds: 10, color: :gold, tires: [{ diameter: 40, tred: :mountain }, { diameter: 50, tred: :slicks }], shocks: true)
        expected = {
          speeds: 10,
          color:  :gold,
          riders: [],
          seat: nil,
          tires: [
            { diameter: 40, tred: :mountain },
            { diameter: 50, tred: :slicks }
          ],
          shocks: true
        }

        expect(bike.to_hash).to eq(expected)
      end
    end

    context "inheritance" do
      it "allows value objects to be inherited from each other" do
        bike = ValueClassTest::MountainBicycle.new(speeds: 10, color: :gold, tires: [{ diameter: 40, tred: :mountain }, { diameter: 50, tred: :slicks }], shocks: true)

        expect(bike.tires.map(&:diameter)).to eq([40, 50])
        expect(bike.tires.map(&:tred)).to eq([:mountain, :slicks])
        expect(bike.shocks).to eq(true)
      end
    end

    context "shorthand declaration using struct" do
      it "allows inheritance from a struct" do
        gear = ValueClassTest::QuickGears.new(first_gear: 20)

        expect(gear.first_gear).to eq(20)
        expect(gear.second_gear).to eq(200)
        expect(gear.third_gear).to eq(200)
      end

      it "allows shorthand types to be assigned" do
        gear = ValueClassTest::QuickerGears.new(first_gear: 20)

        expect(gear.first_gear).to eq(20)
        expect(gear.second_gear).to eq(200)
        expect(gear.third_gear).to eq(200)
      end
    end
  end
end
