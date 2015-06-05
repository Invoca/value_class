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

  it "should be different on different threads" do
    ThreadLocalSpec::Automobile.manufacturer = :Volkswagen
    ThreadLocalSpec::Automobile.model = :Vanagon

    auto = ThreadLocalSpec::Automobile.new

    auto.model_year = 1988
    auto.body_color = :red

    @thread_manufacturer = nil
    @thread_model = nil
    @thread_year  = nil
    @thread_color = nil

    t = Thread.new do
      ThreadLocalSpec::Automobile.manufacturer = :Dodge
      ThreadLocalSpec::Automobile.model = :Colt

      auto.model_year = 1981
      auto.body_color = :blue

      @thread_manufacturer = ThreadLocalSpec::Automobile.manufacturer
      @thread_model = ThreadLocalSpec::Automobile.model
      @thread_year  = auto.model_year
      @thread_color = auto.body_color
    end
    t.join

    expect(ThreadLocalSpec::Automobile.manufacturer).to eq(:Volkswagen)
    expect(@thread_manufacturer).to eq(:Dodge)

    expect(ThreadLocalSpec::Automobile.model).to eq(:Vanagon)
    expect(@thread_model).to eq(:Colt)

    expect(auto.model_year).to eq(1988)
    expect(@thread_year).to eq(1981)

    expect(auto.body_color).to eq(:red)
    expect(@thread_color).to eq(:blue)
  end
end
