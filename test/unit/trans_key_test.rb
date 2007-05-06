require File.dirname(__FILE__) + '/../test_helper'

class TransPhraseTest < Test::Unit::TestCase


  def test_find_monday
    key = TransPhrase['Monday']
    assert_equal 13, key[:id]
    assert_equal 'lundi', key['fr']
    assert_equal 'lundi', TransPhrase['Monday']['fr']
  end
  
  def test_set_value
    assert TransPhrase.translate('Monday').set('de','Montag')
    assert_equal 3, TransPhrase.translate('Monday').size
    assert_equal 'Montag', TransPhrase['Monday']['de']
  end
  
  def test_set_value_attr
    @key = TransPhrase.translate('Monday')
    @key.lang = 'es'
    @key.value = 'Lunes'
    assert @key.save
    assert_equal 'Lunes', TransPhrase['Monday']['es']
  end
  
  def test_set_value_bad_attr
    @key = TransPhrase.translate('Monday')
    @key.value = 'Lunes'
    assert !@key.save
    assert_equal @key.errors[:lang], 'not set'
  end
  
  def test_get_value_with_attr
    @key = TransPhrase.translate('Monday')
    @key.lang = 'fr'
    assert_equal 'lundi', @key.value
  end
  
  def test_default_value
    assert_equal '%Y-%m-%d', TransPhrase['long_date']['io']
    bak = ZENA_ENV[:default_lang]
    ZENA_ENV[:default_lang] = 'fr'
    TransPhrase.clear
    assert_equal '%d.%m.%Y', TransPhrase['long_date']['io']
    ZENA_ENV[:default_lang] = bak
  end
  
  def test_no_value
    assert_equal 'yoba', TransPhrase['yoba']['en']
  end
end
