require File.dirname(__FILE__) + '/../test_helper'
class AdditionsTest < ZenaTestUnit

  def setup
    super
  end
  
  def test_zip_fixtures
    assert_equal zips_zip(:zena_counter), Node.connection.execute("select zip from zips where site_id=1").fetch_row[0].to_i
  end
  
  def test_next_zip
    assert_raise(Zena::BadConfiguration) { Node.next_zip(88) }
    assert_equal zips_zip(:zena_counter ) + 1, Node.next_zip(1)
    assert_equal zips_zip(:ocean_counter) + 1, Node.next_zip(2)
    assert_equal zips_zip(:zena_counter ) + 2, Node.next_zip(1)
  end
  
  def test_next_zip_rollback
    assert_raise(Zena::BadConfiguration) { Node.next_zip(88) }
    assert_equal zips_zip(:zena_counter ) + 1, Node.next_zip(1)
    assert_equal zips_zip(:ocean_counter) + 1, Node.next_zip(2)
    assert_equal zips_zip(:zena_counter ) + 2, Node.next_zip(1)
  end
end
