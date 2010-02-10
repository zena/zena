module Property
  module Serialization
    # Use YAML to encode properties. This method is the slowest of all
    # and you should use JSON if you haven't got good reasons not to.
    module YAML
      module ClassMethods
        # Returns true if the given class can be serialized with YAML
        def validate_property_class(klass)
          true
        end
      end

      def self.included(base)
        base.extend ClassMethods
      end

      # Encode properties with YAML
      def encode_properties(properties)
        ::YAML.dump(properties)
      end

      # Decode properties from YAML
      def decode_properties(string)
        ::YAML::load(string)
      end

    end # Yaml
  end # Serialization
end # Property