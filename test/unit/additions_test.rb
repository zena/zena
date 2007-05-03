require File.dirname(__FILE__) + '/../test_helper'
class AdditionsTest < ZenaTestUnit

  def setup
    super
  end
  
  def test_zip_fixtures
    assert_equal zips_zip(:zena_counter), Node.connection.execute("select zip from zips where site_id=1").fetch_row[0].to_i
  end
  
  def test_fetch_ids
    assert_equal ["1","2","3"], Node.fetch_ids("SELECT id FROM nodes WHERE id IN (1,2,3)")
    assert_equal ["1","2","3"], Node.fetch_ids("id IN (1,2,3)")
    assert_equal ["11","12","13"], Node.fetch_ids("id IN (1,2,3)", :zip)
  end
  
  def test_fetch_list
    assert_equal [{:id=>"1", :name=>"zena"},{:id=>"2", :name=>"people"}, {:id=>"3", :name=>"ant"}], Node.fetch_list("SELECT id, name FROM nodes WHERE id IN (1,2,3)", :id, :name)
    assert_equal [{:id=>"1", :name=>"zena"},{:id=>"2", :name=>"people"}, {:id=>"3", :name=>"ant"}], Node.fetch_list("id IN (1,2,3)", :id, :name)
    assert_equal [{:zip=>"11", :rgroup_id=>"1"},{:zip=>"12", :rgroup_id=>"1"}, {:zip=>"13", :rgroup_id=>"0"}], Node.fetch_list("id IN (1,2,3)", :zip, :rgroup_id)
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
