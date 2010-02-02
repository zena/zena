module Dynamo
  module Serialization
    module YAML

      def encode(data)
        (::YAML.dump(data)) if data
      end

      def decode(string)
        return string unless string.is_a?(String) && string =~ /^---/
        ::YAML::load(string) rescue string
      end

    end # Yaml
  end # Serialization
end # Dynamo