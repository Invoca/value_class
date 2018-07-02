# frozen_string_literal: true

module ValueClass
  module Constructable
    extend ActiveSupport::Concern

    include ValueClass

    def clone_config
      config = self.class.config_class.new
      self.class.value_attributes.each do |attr|
        current_value = send(attr.name)
        dup_value =
          begin
            current_value.dup
          rescue TypeError
            current_value
          end
        config.send("#{attr.name}=", dup_value)
      end
      yield config
      self.class.new(config)
    end

    module ClassMethods
      # Constructs an instance using the configuration created in the passed in block.
      def config
        config = config_class.new
        value_attributes.each do |attr|
          if attr.default
            config.send("#{attr.name}=", attr.default)
          end
        end
        yield config
        new(config)
      end

      def config_class
        unless @config_class
          @config_class = Class.new

          value_attributes.each do |attribute|
            # Define assignment operator
            @config_class.send(:attr_writer, attribute.name)

            # Define accessor (which also allows assignment from blocks
            if (class_name = attribute.options[:class_name])
              config_class.class_eval <<-EORUBY, __FILE__, __LINE__ + 1
                def #{attribute.name}(&blk)
                  if blk
                    @#{attribute.name} = #{class_name}.config { |config| yield config }
                  end
                  @#{attribute.name}
                end
              EORUBY
            else
              config_class.class_eval <<-EORUBY, __FILE__, __LINE__ + 1
                def #{attribute.name}(value = nil)
                  unless value.nil?
                    @#{attribute.name} = value
                  end
                  @#{attribute.name}
                end
              EORUBY
            end

            # Define insert method
            if (insert_method = attribute.options[:insert_method])
              if (class_name = attribute.options[:list_of_class])
                config_class.class_eval <<-EORUBY, __FILE__, __LINE__ + 1
                  def #{insert_method}(value=nil, &blk)
                    if blk
                      @#{attribute.name} << #{class_name}.config { |config| yield config }
                    else
                      @#{attribute.name} << #{class_name}.new(value)
                    end
                    @#{attribute.name}
                  end
                EORUBY
              else
                config_class.class_eval <<-EORUBY, __FILE__, __LINE__ + 1
                  def #{insert_method}(value)
                    @#{attribute.name} << value
                    @#{attribute.name}
                  end
                EORUBY
              end
            end
          end
        end
        @config_class
      end
    end
  end
end
