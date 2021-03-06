# frozen_string_literal: true

module ValueClass
  class Attribute
    attr_reader :name, :options, :limit

    OPTIONS = {
      description: "A description of the attribute.",
      default: "The default value for this parameter.",
      class_name: "The name of the value class for this attribute.  Allows for construction from a nested hash.",
      list_of_class: "Used to declare an attribute that is a list of a class.",
      required: "If true, the parameter is required",
      limit: "The set of valid values",
      insert_method: "The name of the method to create to allow inserting into a list during progressive construction"
    }.freeze

    def initialize(name, options)
      if (invalid_options = options.keys - OPTIONS.keys).any?
        raise ArgumentError, "Unknown option(s): #{invalid_options.join(',')}"
      end

      @name = name.to_sym.freeze
      @options = options.freeze
      @limit = options[:limit]
    end

    def description(prefix = "")
      if options[:description]
        "#{prefix}#{name}: #{options[:description]}"
      else
        "#{prefix}#{name}"
      end
    end

    def get_value(config)
      raw_value = raw_value(config)

      cast_value = cast_value(raw_value)

      if cast_value.nil? && options[:required]
        raise ArgumentError, "must provide a value for #{name}"
      end

      if !cast_value.nil? && limit && !limit.include?(cast_value)
        raise ArgumentError, "invalid value #{cast_value.inspect} for #{name}. allowed values #{limit.inspect}"
      end

      if cast_value.nil?
        default
      else
        cast_value
      end
    end

    def hash_value(raw_value)
      if options[:list_of_class] && raw_value.is_a?(Array)
        raw_value.map(&:to_hash)
      elsif options[:class_name] && raw_value
        raw_value.to_hash
      else
        raw_value
      end
    end

    def default
      value = options[:default]
      begin
        value.dup
      rescue TypeError
        value
      end
    end

    private

    def cast_value(raw_value)
      if options[:list_of_class] && raw_value.is_a?(Array)
        inner_class = options[:list_of_class]
        raw_value.map { |v| inner_class.constantize.new(v).freeze }
      elsif options[:class_name] && raw_value
        options[:class_name].constantize.new(raw_value).freeze
      else
        raw_value
      end
    end

    def raw_value(config)
      if config.is_a?(Hash)
        config[name]
      else
        config.send(name)
      end
    end
  end
end
