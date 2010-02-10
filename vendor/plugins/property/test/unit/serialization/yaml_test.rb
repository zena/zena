require "test_helper"
require 'property/serialization/yaml'

class MyYAML
  include Property::Serialization::YAML
end

class MyYAMLTest < Test::Unit::TestCase

  should_encode_and_decode_properties

end