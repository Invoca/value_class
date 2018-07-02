# frozen_string_literal: true

require 'active_record'
require 'attr_comparable'
require 'active_support/core_ext'

require 'value_class/attribute'

module ValueClass
  extend ActiveSupport::Concern

  # Default constructor
  def initialize(config = {})
    check_constructor_params(config)
    self.class.declare_comparison_operators
    self.class.value_attributes.each do |attribute|
      instance_variable_set("@#{attribute.name}", attribute.get_value(config).freeze)
    end
  end

  # TODO: These need to be added to attr_comparible
  def eql?(other)
    self == other
  end

  def hash
    self.class.value_attributes.map do |attribute|
      instance_variable_get("@#{attribute.name}")
    end.hash
  end

  def to_hash
    self.class.value_attributes.inject(ActiveSupport::HashWithIndifferentAccess.new()) do |hash, attribute|
      # Attributes are frozen, but hash with indifferent access mutates values (!!!), so we have to dup
      # in order to get a value we can use
      unsafe_version = attribute.hash_value(instance_variable_get("@#{attribute.name}"))
      safe_version =
        begin
          unsafe_version.dup
        rescue TypeError
          unsafe_version
        end

      hash[attribute.name] = safe_version
      hash
    end
  end

  protected
  def check_constructor_params(config)
    if config.is_a?(Hash)
      extra_keys = config.keys - self.class.value_attributes.map(&:name)
      extra_keys.empty? or raise ArgumentError, "unknown attribute #{extra_keys.join(", ")}"
    end
  end

  module ClassMethods
    def value_description(value = nil)
      if value
        @value_description = value
      end
      @value_description
    end

    def value_list_attr(attribute_name, options= {})
      value_attr(attribute_name, options.merge(default:[], class_name: nil, list_of_class: options[:class_name]))
    end

    def value_attr(attribute_name, options= {})
      attribute = Attribute.new(attribute_name, options)
      value_attributes << attribute

      attr_reader(attribute.name)
    end

    def value_attrs(*args)
      options = args.extract_options!
      args.each { |arg| value_attr(arg, options) }
    end

    def config_help(prefix = "")
      [
          "#{name}: #{value_description}",
          "  attributes:",
          value_attributes.map { |ca| ca.description(prefix + "    ") }
      ].flatten.join("\n") + "\n"
    end

    def value_attributes
      @value_attrs ||= []
    end

    def declare_comparison_operators
      unless @comparison_operators_declared
        @comparison_operators_declared = true

        include AttrComparable
        attr_compare(value_attributes.map(&:name))
      end
    end

    def inherited(new_child_class)
      value_attributes.each { |attr| new_child_class.value_attributes << attr }
    end
  end

  def self.struct(*args)
    Class.new do
      include ValueClass::Constructable
      value_attrs *args
    end
  end
end

# These build off of the above, so they are required last
require 'value_class/constructable'
require 'value_class/thread_local_attribute'

