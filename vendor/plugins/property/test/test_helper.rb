$LOAD_PATH.unshift((Pathname(__FILE__).dirname +  '..' + 'lib').expand_path)
require 'rubygems'
require 'test/unit'
require 'shoulda'
require 'active_record'
require 'property'
require 'shoulda_macros/serialization'

class Test::Unit::TestCase

  def assert_attribute(value, attr_name, object=subject)
    assert_equal value, object.send(attr_name)
    assert_equal value, object[attr_name]
    assert_equal value, object.attributes[attr_name]
    assert_equal value, object.properties=erties[attr_name]
  end

end