require 'value_class'

module ConstructableSpec
  class BikeTire
    include ValueClass::Constructable

    value_attr :diameter, description: "The diameter in inches"
    value_attr :tred,     description: "The tred on the tire"
  end

  class BikeSeat
    include ValueClass::Constructable

    value_attr :size, description: "The size of the bike seat in inches"
    value_attr :color
  end

  class Bicycle
    include ValueClass::Constructable

    value_description "For riding around town"
    value_attr :speeds
    value_attr :color, default: :orange
    value_attr :seat, class_name: 'ConstructableSpec::BikeSeat'

    value_list_attr :riders, insert_method: :add_rider
    value_list_attr :tires, insert_method: :tire, class_name: 'ConstructableSpec::BikeTire'
  end

  class Headlight
    include ValueClass::Constructable
    value_attr :lumens, required: true
  end
end

describe ValueClass::Constructable do
  context "configurable" do
    it "supports constructing instances from config" do
      bike = ConstructableSpec::Bicycle.config do |bicycle|
        bicycle.speeds = 10
        bicycle.color = :blue
      end

      expect(bike.speeds).to eq(10)
      expect(bike.color).to eq(:blue)
    end

    it "supports nested config" do
      bike = ConstructableSpec::Bicycle.config do |bicycle|
        bicycle.speeds = 10
        bicycle.color = :blue
        bicycle.seat do |seat|
          seat.color = :green
          seat.size  = :large
        end
      end

      expect(bike.speeds).to eq(10)
      expect(bike.color).to eq(:blue)
      expect(bike.seat.color).to eq(:green)
      expect(bike.seat.size).to eq(:large)
    end

    it "supports assignment without the equals operator" do
      bike = ConstructableSpec::Bicycle.config do |bicycle|
        bicycle.speeds 10
        bicycle.color  :blue
        bicycle.seat do |seat|
          seat.color :green
          seat.size  :large
        end
      end

      expect(bike.speeds).to eq(10)
      expect(bike.color).to eq(:blue)
      expect(bike.seat.color).to eq(:green)
      expect(bike.seat.size).to eq(:large)
    end

    it "supports accessing variables from outside the scope" do
      seat_color = :magenta

      bike = ConstructableSpec::Bicycle.config do |bicycle|
        bicycle.seat do |seat|
          seat.color = seat_color
        end
      end

      expect(bike.seat.color).to eq(:magenta)
    end

    it "supports assigning hashes to typed attributes" do
      bike = ConstructableSpec::Bicycle.config do |bicycle|
        bicycle.seat = { color: :blue }
      end

      expect(bike.seat.color).to eq(:blue)
    end

    # TODO - this is pretty lame so far
    it "supports generating a description" do
      expected_description  = <<-EOF.gsub(/^ {8}/, '')
        ConstructableSpec::Bicycle: For riding around town
          attributes:
            speeds
            color
            seat
            riders
            tires
      EOF

      expect(ConstructableSpec::Bicycle.config_help).to eq(expected_description)
    end


    it "supports specifying a default attribute" do
      bike = ConstructableSpec::Bicycle.config { |_| }

      expect(bike.color).to eq(:orange)
    end

    it "be able to construct the class with a hash" do
      bike = ConstructableSpec::Bicycle.new(speeds: 10, color: :gold)
      expect(bike.color).to eq(:gold)
    end

    context "lists" do
      it "should be able to directly assign lists" do
        bike = ConstructableSpec::Bicycle.config do |bicycle|
          bicycle.riders = [:bob, :victor]
        end

        expect(bike.riders).to eq([:bob, :victor])
      end

      it "should be able to configure using the add method" do
        bike = ConstructableSpec::Bicycle.config do |bicycle|
          bicycle.add_rider :bob
          bicycle.add_rider :victor
        end

        expect(bike.riders).to eq([:bob, :victor])
      end

      it "should be able to use the add method to add nested classes" do
        bike = ConstructableSpec::Bicycle.config do |bicycle|
          bicycle.tire do |tire_config|
            tire_config.diameter = 40
            tire_config.tred = :mountain
          end

          bicycle.tire do |tire_config|
            tire_config.diameter = 50
            tire_config.tred = :slicks
          end
        end

        expect(bike.tires.map(&:diameter)).to eq([40, 50])
        expect(bike.tires.map(&:tred)).to eq([:mountain, :slicks])
      end

      it "should be able to use the add method to add with hashes" do
        bike = ConstructableSpec::Bicycle.config do |bicycle|
          bicycle.tire diameter: 40, tred: :mountain
          bicycle.tire diameter: 50, tred: :slicks
        end

        expect(bike.tires.map(&:diameter)).to eq([40, 50])
        expect(bike.tires.map(&:tred)).to eq([:mountain, :slicks])
      end

      it "be able to construct the class with a hash" do
        bike = ConstructableSpec::Bicycle.new(speeds: 10, color: :gold, tires: [{ diameter: 40, tred: :mountain}, {diameter: 50, tred: :slicks}] )

        expect(bike.tires.map(&:diameter)).to eq([40, 50])
        expect(bike.tires.map(&:tred)).to eq([:mountain, :slicks])
      end

      it "be able to assign a hash to the attribute during config" do
        bike = ConstructableSpec::Bicycle.config do |bicycle|
          bicycle.tires = [{ diameter: 40, tred: :mountain}, {diameter: 50, tred: :slicks}]
        end

        expect(bike.tires.map(&:diameter)).to eq([40, 50])
        expect(bike.tires.map(&:tred)).to eq([:mountain, :slicks])
      end

    end
  end

  context "validations" do
    it "should raise an exception if a required parameter is missing" do
      expect { ConstructableSpec::Headlight.new }.to  raise_error(ArgumentError, "must provide a value for lumens")

    end
  end
end

