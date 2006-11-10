require File.dirname(__FILE__) + '/../test_helper'

class TransTest < Test::Unit::TestCase
  fixtures :trans, :trans_values

  def test_find_monday
    key = Trans['Monday']
    assert_equal 1, key[:id]
    assert_equal 'lundi', key['fr']
    assert_equal 'lundi', Trans['Monday']['fr']
  end
  
  def test_create_new_key
    assert_nil Trans.find_by_key('yoba')
    key = Trans['yoba']
    assert_not_nil Trans.find_by_key('yoba')
  end
  
  def test_set_value
    assert Trans['Monday']['de'] = 'Montag'
    assert_equal 3, Trans['Monday'].size
    assert_equal 'Montag', Trans['Monday']['de']
  end
  
  def test_default_value
    assert_equal '%Y-%m-%d', Trans['long_date']['io']
    bak = ZENA_ENV[:default_lang]
    ZENA_ENV[:default_lang] = 'fr'
    assert_equal '%d.%m.%Y', Trans['long_date']['io']
    ZENA_ENV[:default_lang] = bak
  end
  
  def test_no_value
    assert_equal 'yoba', Trans['yoba']['en']
  end
end
