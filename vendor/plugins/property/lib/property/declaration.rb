module Property

  # Property::Declaration module is used to declare property definitions in a Class. The module
  # also manages property inheritence in sub-classes.
  module Declaration

    def self.included(base)
      base.class_eval do
        extend  ClassMethods
        include InstanceMethods

        class << self
          attr_accessor :own_property_columns
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

        def column(name, default, type, options)
          if @klass.super_property_columns[name.to_s]
            raise TypeError.new("Property '#{name}' is already defined in a superclass.")
          else
            (@klass.own_property_columns ||= {})[name] = Property::Column.new(name, default, type, options)
          end
        end

        # If someday we find the need to insert other native classes directly in the DB, we
        # could use this:
        # p.serialize MyClass, xxx, xxx
        # def serialize(klass, name, options={})
        #   if @klass.super_property_columns[name.to_s]
        #     raise TypeError.new("Property '#{name}' is already defined in a superclass.")
        #   elsif !@klass.validate_property_class(type)
        #     raise TypeError.new("Custom type '#{type}' cannot be serialized.")
        #   else
        #     # Find a way to insert the type (maybe with 'serialize'...)
        #     # (@klass.own_property_columns ||= {})[name] = Property::Column.new(name, type, options)
        #   end
        # end

        # def string(*args)
        #   options = args.extract_options!
        #   column_names = args
        #   default = options.delete(:default)
        #   column_names.each { |name| column(name, default, 'string', options) }
        # end
        %w( string text integer float decimal datetime timestamp time date binary boolean ).each do |column_type|
          class_eval <<-EOV
            def #{column_type}(*args)
              options = args.extract_options!
              column_names = args
              default = options.delete(:default)
              column_names.each { |name| column(name, default, '#{column_type}', options) }
            end
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
      def property_columns
        super_property_columns.merge(self.own_property_columns || {})
      end

      def property_column_names
        property_columns.keys
      end

      def super_property_columns
        if superclass.respond_to?(:property_columns)
          superclass.property_columns
        else
          {}
        end
      end
    end # ClassMethods

    module InstanceMethods

      protected
        def properties_validation
          properties.validate
        end
    end # InsanceMethods
  end # Declaration
end # Property