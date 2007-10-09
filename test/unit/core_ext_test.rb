require 'test/unit'
require File.join(File.dirname(__FILE__), '../../lib/core_ext/string')

class StringExtTest < Test::Unit::TestCase  
  def test_iso_format
    assert_equal Time.utc(2007,10,16,15,30,10), "2007-10-16 15:30:10".to_utc('%Y-%m-%d %H:%M:%S')
  end
  
  def test_swiss_format
    assert_equal Time.utc(2007,10,16,15,30), "16.10.2007 15:30".to_utc('%d.%m.%Y %H:%M')
  end
  
  def test_date_only
    assert_equal Time.utc(1975,10,16), "10/16/1975".to_utc('%m/%d/%Y')
  end
end