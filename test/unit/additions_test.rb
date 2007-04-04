require File.dirname(__FILE__) + '/../test_helper'
class AdditionsTest < ZenaTestUnit

  def setup
    super
  end
  
  def test_zip_fixtures
    assert_equal 34, Node.connection.execute("select zip from zips where site_id=1").fetch_row[0].to_i
  end
  
  def test_next_zip
    assert_raise(Zena::BadConfiguration) { Node.next_zip(88) }
    assert_equal 35, Node.next_zip(1)
    assert_equal 2, Node.next_zip(2)
    assert_equal 36, Node.next_zip(1)
  end
  
  def test_next_zip_rollback
    assert_raise(Zena::BadConfiguration) { Node.next_zip(88) }
    assert_equal 35, Node.next_zip(1)
    assert_equal 2, Node.next_zip(2)
    assert_equal 36, Node.next_zip(1)
  end
end
