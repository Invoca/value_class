require 'active_support'

module ActiveTableSet
  module ModelComparison
    extend ActiveSupport::Concern

    module ClassMethods
      def attr_accessor(*vars)
        @attributes ||= []
        @attributes.concat vars
        super(*vars)
      end

      def attributes
        @attributes
      end
    end

    def attributes
      self.class.attributes
    end

    def ==(other_model)
      equality_check(other_model)
    end

    def eql?(other_model)
      equality_check(other_model)
    end

    private

    def equality_check(other_model)
      attributes.select { |attr| self.send(attr) != other_model.send(attr) }.empty?
    end
  end
end
