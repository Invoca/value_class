require 'value_class'

module ValueClassTest
  class BikeTire
    include ValueClass::Immutable

    value_attr :diameter, description: "The diameter in inches"
    value_attr :tred,     description: "The tred on the tire"
  end

  class BikeSeat
    include ValueClass::Immutable

    value_attr :size, description: "The size of the bike seat in inches"
    value_attr :color
  end

  class Bicycle
    include ValueClass::Immutable

    value_description "For riding around town"
    value_attr :speeds
    value_attr :color, default: :orange
    value_attr :seat, class_name: 'ValueClassTest::BikeSeat'

    value_list_attr :riders
    value_list_attr :tires, class_name: 'ValueClassTest::BikeTire'
  end

  class Headlight
    include ValueClass::Immutable
    value_attr :lumens, required: true
  end

  class HandleBar
    include ValueClass::Immutable
    value_attrs :style, :grip, :brakes, :headlight, :bell
  end

  class Gears
    include ValueClass::Immutable
    value_attrs :first_gear, :second_gear, :third_gear, default: 200
  end
end


describe ValueClass::Immutable do
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
        bike = ValueClassTest::Bicycle.new(speeds: 10, color: :gold, tires: [{ diameter: 40, tred: :mountain}, {diameter: 50, tred: :slicks}] )

        expect(bike.tires.map(&:diameter)).to eq([40, 50])
        expect(bike.tires.map(&:tred)).to eq([:mountain, :slicks])
      end
    end

    it "should raise an exception if a required parameter is missing" do
      expect { ValueClassTest::Headlight.new }.to  raise_error(ArgumentError, "must provide a value for lumens")
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
  end
end
