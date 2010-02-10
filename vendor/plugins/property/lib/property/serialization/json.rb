module Property
  module Serialization
    # Use JSON to encode properties. This is the serialization best option. It's
    # the fastest and does not have any binary format issues. You just have to
    # provide 'self.create_json' and 'to_json' methods for the classes you want
    # to serialize.
    module JSON
      module ClassMethods
        NATIVE_TYPES = [Hash, Array, Integer, Float, String, TrueClass, FalseClass, NilClass]

        # Returns true if the given class can be serialized with JSON
        def validate_property_class(klass)
          if NATIVE_TYPES.include?(klass) ||
             (klass.respond_to?('json_create') && klass.instance_methods.include?('to_json'))
            true
          else
            raise TypeError.new("Cannot serialize #{klass}. Missing 'self.create_json' and 'to_json' methods.")
          end
        end
      end

      def self.included(base)
        base.extend ClassMethods
      end

      # Encode properties with Marhsal
      def encode_properties(properties)
        properties.to_json
      end

      # Decode Marshal encoded properties
      def decode_properties(string)
        ::JSON.parse(string)
      end

    end # JSON
  end # Serialization
end # Property