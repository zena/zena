module Property

  # Property::Declaration module is used to declare property definitions in a Class. The module
  # also manages property inheritence in sub-classes.
  module Declaration

    def self.included(base)
      base.class_eval do
        extend  ClassMethods
        include InstanceMethods

        class << self
          attr_accessor :own_property_definitions
        end

        validate :properties_validation, :if => :properties
      end
    end

    module ClassMethods
      # Use this class method to declare properties that will be used in your models. Note
      # that you must provide string keys. Example:
      #  property 'phone', String
      #
      def property(name, type, options={})
        if super_property_definitions[name.to_s]
          raise TypeError.new("Property '#{name}' is already defined in a superclass.")
        elsif !validate_property_class(type)
          raise TypeError.new("Property type '#{type}' cannot be serialized.")
        else
          (self.own_property_definitions ||= {})[name] = PropertyDefinition.new(name, type, options)
        end
      end

      # Return the list of all properties defined for the current class, including the properties
      # defined in the parent class.
      def property_definitions
        super_property_definitions.merge(self.own_property_definitions || {})
      end

      def super_property_definitions
        if superclass.respond_to?(:property_definitions)
          superclass.property_definitions
        else
          {}
        end
      end
    end # ClassMethods

    module InstanceMethods

      protected
        def properties_validation
          property_definitions = self.class.property_definitions

          properties.each do |key, value|
            if property_definition = property_definitions[key]
              if default = property_definition.validate(value, self)
                properties[key] = default
              end
            else
              errors.add("#{key}", 'property not declared.')
            end
          end
        end
    end # InsanceMethods
  end # Declaration
end # Property