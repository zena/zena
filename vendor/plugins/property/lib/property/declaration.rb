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
          attr_accessor :property_definition_proxy
        end

        validate :properties_validation, :if => :properties
      end
    end

    module ClassMethods
      class DefinitionProxy
        def initialize(klass)
          @klass = klass
        end

        def column(name, type, options)
          if @klass.super_property_definitions[name.to_s]
            raise TypeError.new("Property '#{name}' is already defined in a superclass.")
          else
            (@klass.own_property_definitions ||= {})[name] = PropertyDefinition.new(name, type, options)
          end
        end

        # If someday we find the need to insert other native classes directly in the DB, we
        # could use this:
        # p.serialize MyClass, xxx, xxx
        # def serialize(klass, name, options={})
        #   if @klass.super_property_definitions[name.to_s]
        #     raise TypeError.new("Property '#{name}' is already defined in a superclass.")
        #   elsif !@klass.validate_property_class(type)
        #     raise TypeError.new("Custom type '#{type}' cannot be serialized.")
        #   else
        #     # Find a way to insert the type (maybe with 'serialize'...)
        #     # (@klass.own_property_definitions ||= {})[name] = PropertyDefinition.new(name, type, options)
        #   end
        # end

        %w( string text integer float decimal datetime timestamp time date binary boolean ).each do |column_type|
          class_eval <<-EOV
            def #{column_type}(*args)                                               # def string(*args)
              options = args.extract_options!                                       #   options = args.extract_options!
              column_names = args                                                   #   column_names = args
                                                                                    #
              column_names.each { |name| column(name, '#{column_type}', options) }  #   column_names.each { |name| column(name, 'string', options) }
            end                                                                     # end
          EOV
        end
      end

      # Use this class method to declare properties that will be used in your models. Note
      # that you must provide string keys. Example:
      #  property.string 'phone', :default => ''
      #
      # You can also use a block:
      #  property do |p|
      #    p.string 'phone', 'name', :default => ''
      #  end
      def property
        proxy = self.property_definition_proxy ||= DefinitionProxy.new(self)
        if block_given?
          yield proxy
        end
        proxy
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
          properties.owner = self
          properties.validate
        end
    end # InsanceMethods
  end # Declaration
end # Property