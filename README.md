# ValueClass

Provides a simple mechanism for declaring a class with complex attributes.  Instances of the class can be progressively
constructed in a using a block.  The class is immutable outside of the block.   This is useful for building simple
configuration DSLs.  

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'value_class'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install value_class

## Usage

The following class declaration allow a bicycle to be declared: 
 
```ruby
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
    value_attr :seat, class_name: 'BikeSeat'

    value_list_attr :riders, insert_method: :add_rider
    value_list_attr :tires, insert_method: :tire, class_name: 'BikeTire'
  end
```

Given the above declarations, you can then configure a bicycle with the following code.

```ruby
  bike = Bicycle.config do |bicycle|
    bicycle.speeds 10
    bicycle.color  :blue
    bicycle.seat do |seat|
      seat.color :green
      seat.size  :large
    end
  end
```

You can also directly declare the class:

```ruby 
  bike = Bicycle.new(speeds: 10, color: :gold, tires: [{ diameter: 40, tred: :mountain }, { diameter: 50, tred: :slicks }])
```

If you have a simple class, ValueClass provides a replacement for ruby struct that allows for a quick class declaration.

```ruby
        
  Gears = ValueClass.struct(:first_gear, :second_gear, :third_gear, default: 200)
  gear = Gears.new(first_gear: 20) 
```  

Once an instance of a class is returned. It is immutable: it is frozen and all if its attributes are frozen.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/console` for an interactive prompt that will allow you to experiment. 

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

### Running Tests

Tests in this gem are written in Rspec and can be executed through the main rake task for the repo
```bash
bundle exec rake
```

If there is a subset of tests you would like to run, you can add the `focus: true` tag to the test or context to only run the subset of tests.

## Contributing

1. Fork it ( https://github.com/invoca/value_class/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
4. Make sure the tests pass: `rspec spec`
5. Create a new Pull Request
