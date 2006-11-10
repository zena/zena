require File.dirname(__FILE__) + '/../test_helper'

class TransTest < Test::Unit::TestCase
  fixtures :trans, :trans_values

  def test_find_monday
    key = Trans.translate('Monday')
    assert_equal 1, key[:id]
    assert_equal 'lundi', key.into('fr')
    assert_equal 'lundi', Trans.translate('Monday').into('fr')
  end
  
  def test_create_new_key
    assert_nil Trans.find_by_key('yoba')
    key = Trans.translate('yoba')
    assert_not_nil Trans.find_by_key('yoba')
  end
  
  def test_set_value
    assert Trans.translate('Monday').set('de','Montag')
    assert_equal 3, Trans.translate('Monday').size
    assert_equal 'Montag', Trans.translate('Monday').into('de')
  end
  
  def test_default_value
    assert_equal '%Y-%m-%d', Trans.translate('long_date').into('io')
    bak = ZENA_ENV[:default_lang]
    ZENA_ENV[:default_lang] = 'fr'
    assert_equal '%d.%m.%Y', Trans.translate('long_date').into('io')
    ZENA_ENV[:default_lang] = bak
  end
  
  def test_no_value
    assert_equal 'yoba', Trans.translate('yoba').into('en')
  end
end
