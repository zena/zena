require File.dirname(__FILE__) + '/../test_helper'

class ContactVersionTest < ActiveSupport::TestCase
  include Zena::Test::Unit
  def setup; login(:anon); end

  def test_set_name
    login(:tiger)
    node = secure!(Node) { nodes(:tiger) }
    node.c_first_name = 'King'
    node.v_title = ''
    assert node.save
    assert_equal "tiger", node.name
    assert_equal "King Tigris Sumatran", node.v_title
  end
  
  def test_set_content_name
    login(:tiger)
    assert node = secure!(Contact) { Contact.create(:v_title=>"Roger Rabbit", :parent_id => nodes_id(:people)) }
    assert !node.new_record?
    assert_equal "RogerRabbit", node.name
    assert_equal "Roger", node.c_first_name
    assert_equal "Rabbit", node.c_name
    assert_equal "Roger Rabbit", node.v_title
    assert_equal "Roger Rabbit", node.fullname
  end
  
  def test_v_title_not_in_sync
    login(:tiger)
    node = secure!(Node) { nodes(:tiger) }
    assert_equal 'Panther Tigris Sumatran', node.fullname
    assert_equal 'Tiger', node.v_title
    assert node.update_attributes(:c_first_name => "Pathy")
    assert_equal 'Pathy Tigris Sumatran', node.fullname
    assert_equal 'Tiger', node.v_title
  end

  def test_v_title_follow_content
    login(:tiger)
    node = secure!(Node) { nodes(:tiger) }
    assert node.update_attributes(:v_title => node.fullname)
    node = secure!(Node) { nodes(:tiger) } # reload
    assert_equal 'Panther Tigris Sumatran', node.fullname
    assert_equal 'Panther Tigris Sumatran', node.v_title
    assert node.update_attributes(:c_first_name => "Pathy")
    assert_equal 'Pathy Tigris Sumatran', node.fullname
    assert_equal 'Pathy Tigris Sumatran', node.v_title
  end
end
