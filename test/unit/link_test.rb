require 'test_helper'

class LinkTest < ActiveSupport::TestCase
  include Zena::Test::Unit
  def setup; login(:anon); end

  def test_link_through
    node = secure!(Node) { nodes(:cleanWater) }
    link = Link.find_through(node, links_id(:status_hot_for_cleanWater))
    assert_equal 'hot', link.role
  end
  
  def test_update_attributes_with_transformations
    login(:lion)
    node = secure!(Node) { nodes(:cleanWater) }
    assert_equal nodes_id(:status), node.find(:first, 'hot')[:id]
    link = Link.find_through(node, links_id(:status_hot_for_cleanWater))
    link.update_attributes_with_transformations('role' => 'hot', 'other_id' => nodes_zip(:lake), 'comment' => 'pop')
    assert_equal 'hot', link.role
    assert_equal nodes_zip(:lake), link.other_zip
    # change propagated to caller node.
    assert_equal 'pop', node.l_comment
    node = secure!(Node) { nodes(:cleanWater) }
    assert_equal nodes_id(:lake), node.find(:first, 'hot')[:id]
  end
  
  def test_node_zip
    login(:lion)
    node = secure!(Node) { nodes(:zena) }
    assert link = Link.find_through(node, links_id(:opening_in_zena))
    assert_equal nodes_zip(:zena), link.this_zip
    assert_equal nodes_zip(:opening), link.other_zip
  end
end