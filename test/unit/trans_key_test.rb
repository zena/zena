require File.dirname(__FILE__) + '/../test_helper'

class TransKeyTest < Test::Unit::TestCase
  fixtures :trans_keys, :trans_values

  def test_find_monday
    key = TransKey.translate('Monday')
    assert_equal 1, key[:id]
    assert_equal 'lundi', key.into('fr')
    assert_equal 'lundi', TransKey.translate('Monday').into('fr')
  end
  
  def test_create_new_key
    assert_nil TransKey.find_by_key('yoba')
    key = TransKey.translate('yoba')
    assert_not_nil TransKey.find_by_key('yoba')
  end
  
  def test_set_value
    assert TransKey.translate('Monday').set('de','Montag')
    assert_equal 3, TransKey.translate('Monday').size
    assert_equal 'Montag', TransKey.translate('Monday').into('de')
  end
  
  def test_default_value
    assert_equal '%Y-%m-%d', TransKey.translate('long_date').into('io')
    bak = ZENA_ENV[:default_lang]
    ZENA_ENV[:default_lang] = 'fr'
    assert_equal '%d.%m.%Y', TransKey.translate('long_date').into('io')
    ZENA_ENV[:default_lang] = bak
  end
  
  def test_no_value
    assert_equal 'yoba', TransKey.translate('yoba').into('en')
  end
end
