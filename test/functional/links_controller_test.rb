require 'test_helper'

class LinksControllerTest < Zena::Controller::TestCase

  def test_route
    assert_equal '/nodes/15/links/99', node_link_path(:node_id => 15, :id => 99)
    assert_equal '/nodes/15/links/99/edit', edit_node_link_path(:node_id => 15, :id => 99)
    assert_equal '/nodes/15/links', node_links_path(:node_id => 15)
  end

  def test_create
    login(:lion)
    node = secure!(Node) { nodes(:letter) }
    assert_nil node.find(:first, 'calendar')
    post 'create', 'node_id' => nodes_zip(:letter), 'link' => {'other_zip' => nodes_zip(:zena).to_s, 'role' => 'calendar', 'comment' => 'super icon'}
    assert_response :success
    node = assigns(:node)
    assert node.errors.empty?
    node = secure!(Node) { nodes(:letter) }
    assert calendar = node.find(:first, 'calendar')
    assert_equal nodes_id(:zena), calendar[:id]
    assert_equal 'super icon', calendar.l_comment
    assert_nil calendar.l_status
  end
end

