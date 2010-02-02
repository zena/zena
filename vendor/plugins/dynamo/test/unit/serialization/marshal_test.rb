require "test_helper"

class MyMarshal
  include Dynamo::Serialization::Marshal
end

class MyMarshalTest < Test::Unit::TestCase

  should_serialization_encode

  should_serialization_decode

  context 'Serialize empty hash' do
    setup do
      @my_marshal = MyMarshal.new
    end

    subject { @my_marshal }

    should 'encode empty hash' do
      encoded = subject.encode({})
      assert subject.decode(encoded)
      assert_equal Hash[], subject.decode(encoded)
    end

    should 'decode empty hash' do
      assert_equal Hash[], subject.decode("BAh7AA==\n")
    end
  end


end