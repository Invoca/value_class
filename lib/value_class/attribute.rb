module ValueClass
  class Attribute
    attr_reader :name, :options
    def initialize( name, options )
      @name = name.freeze
      @options = options.freeze
    end

    def description(prefix="")
      "#{prefix}#{name}"
    end

    def default
      value = options[:default]
      begin
        value.dup
      rescue TypeError
        value
      end
    end
  end
end