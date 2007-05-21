require File.dirname(__FILE__) + '/../test_helper'

class ContactVersionTest < ZenaTestUnit

  def test_truth
    login(:tiger)
    node = secure(Node) { nodes(:tiger) }
    node.c_first_name = 'King'
    assert node.save
    assert_equal "tiger", node.name
    assert_equal "King Tigris Sumatran", node.v_title
  end
end
