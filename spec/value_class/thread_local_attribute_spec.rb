require 'value_class'

module ThreadLocalSpec
  class Automobile
    include ValueClass::ThreadLocalAttribute

    thread_local_class_attr    :manufacturer
    thread_local_class_attr    :model

    thread_local_instance_attr :model_year
    thread_local_instance_attr :body_color
  end
end

describe ValueClass::ThreadLocalAttribute do
  it "should work for class variables" do
    ThreadLocalSpec::Automobile.manufacturer = :Oldsmobile
    ThreadLocalSpec::Automobile.model = :Cutlas
    expect(ThreadLocalSpec::Automobile.manufacturer).to eq(:Oldsmobile)
    expect(ThreadLocalSpec::Automobile.model).to eq(:Cutlas)
  end

  it "should work for instance variables" do
    auto1 = ThreadLocalSpec::Automobile.new
    auto2 = ThreadLocalSpec::Automobile.new

    auto1.model_year = 1975
    auto2.model_year = 1945

    auto1.body_color = :gold
    auto2.body_color = :black

    expect(auto1.model_year).to eq(1975)
    expect(auto2.model_year).to eq(1945)

    expect(auto1.body_color).to eq(:gold)
    expect(auto2.body_color).to eq(:black)
  end

  { Thread => :join, Fiber => :resume }.each do |klass, run_method|
    it "should be different on different #{klass}s" do
      ThreadLocalSpec::Automobile.manufacturer = :Volkswagen
      ThreadLocalSpec::Automobile.model        = :Vanagon

      auto = ThreadLocalSpec::Automobile.new

      auto.model_year = 1988
      auto.body_color = :red

      manufacturer = nil
      model        = nil
      year         = nil
      color        = nil

      t = klass.new do
        ThreadLocalSpec::Automobile.manufacturer = :Dodge
        ThreadLocalSpec::Automobile.model        = :Colt

        auto.model_year = 1981
        auto.body_color = :blue

        manufacturer = ThreadLocalSpec::Automobile.manufacturer
        model        = ThreadLocalSpec::Automobile.model
        year  = auto.model_year
        color = auto.body_color
      end
      t.send(run_method)

      expect(ThreadLocalSpec::Automobile.manufacturer).to eq(:Volkswagen)
      expect(manufacturer).to eq(:Dodge)

      expect(ThreadLocalSpec::Automobile.model).to eq(:Vanagon)
      expect(model).to eq(:Colt)

      expect(auto.model_year).to eq(1988)
      expect(year).to eq(1981)

      expect(auto.body_color).to eq(:red)
      expect(color).to eq(:blue)
    end
  end
end
