require "test_helper"
require 'property/serialization/json'

class MyJSON
  include Property::Serialization::JSON
end

class MyJSONTest < Test::Unit::TestCase

  should_encode_and_decode_properties

end