require "test_helper"

class MyYAML
  include Dynamo::Serialization::YAML
end

class MyYAMLTest < Test::Unit::TestCase

  should_serialization_encode

  should_serialization_decode

end