module Property
  # The Property::Attribute module is included in ActiveRecord model for CRUD operations
  # on properties. These ared stored in a table field called 'properties' and are accessed
  # with #properties or #prop and properties= methods.
  #
  # The properties are encoded et decoded with a serialization tool than you can change by including
  # a Serialization module that should implement 'encode_properties' and 'decode_properties'.
  # The default is to use Marshal through Property::Serialization::Marshal.
  #
  # The attributes= method filters native attributes and properties in order to store
  # them apart.
  #
  module Attribute

    def self.included(base)
      base.class_eval do
        include InstanceMethods
        include Serialization::JSON
        include Declaration
        include Dirty

        before_save :dump_properties

        alias_method_chain :attributes=,  :properties
      end
    end

    module InstanceMethods
      def properties
        @properties ||= load_properties
      end

      alias_method :prop, :properties

      # Define a set of properties. This acts like 'attributes=': it merges the current
      # properties with the list of provided key/values. Note that unlike 'attributes=',
      # the keys must be provided as strings, not symbols. For efficiency reasons and
      # simplification of the API, we do not convert from symbols.
      def properties=(new_properties)
        return if new_properties.nil?
        properties.merge!(new_properties)
      end

      alias_method :prop=, :properties=

      # Force a reload of the properties from the ones stored in the database.
      def reload_properties!
        @properties = load_properties
      end

      private
        def attributes_with_properties=(attributes, guard_protected_attributes = true)
          columns = self.class.column_names
          properties = {}

          attributes.keys.each do |k|
            if !respond_to?("#{k}=") && !columns.include?(k)
              properties[k] = attributes.delete(k)
            end
          end

          self.properties = properties
          self.attributes_without_properties = attributes
        end

        def load_properties
          raw_data = read_attribute('properties')
          prop = raw_data ? decode_properties(raw_data) : Properties.new
          # We need to set the owner to access property definitions and enable
          # type casting on write.
          prop.owner = self
          prop
        end

        def dump_properties
          if @properties
            @properties.compact!
            if !@properties.empty?
              write_attribute('properties', encode_properties(@properties))
            else
              write_attribute('properties', nil)
            end
          else
            write_attribute('properties', nil)
          end
          @properties.clear_changes!
          true
        end
    end # InstanceMethods
  end # Attribute
end # Property