require "test_helper"
require 'property/serialization/marshal'

class MyMarshal
  include Property::Serialization::Marshal
end

class MyMarshalTest < Test::Unit::TestCase

  should_encode_and_decode_properties

end