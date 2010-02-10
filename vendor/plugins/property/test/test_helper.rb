begin
  require "rubygems"
  require "test/unit"
  require "shoulda"
  require "active_record"

  $LOAD_PATH.unshift(File.dirname(__FILE__))
  dir = (Pathname(__FILE__).dirname +  '..' + 'lib').expand_path
  test = (Pathname(__FILE__).dirname).expand_path
  require dir + 'dynamo'
  require test + 'shoulda_macros/serialization.rb'
end

class Test::Unit::TestCase

  def assert_attribute(value, attr_name, object=subject)
    assert_equal value, object.send(attr_name)
    assert_equal value, object[attr_name]
    assert_equal value, object.attributes[attr_name]
    assert_equal value, object.dynamo=erties[attr_name]
  end

end