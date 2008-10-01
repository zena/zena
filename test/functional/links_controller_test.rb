require File.dirname(__FILE__) + '/../test_helper'
require 'links_controller'

# Re-raise errors caught by the controller.
class LinksController; def rescue_action(e) raise e end; end

class LinksControllerTest < ZenaTestController
  
  def setup
    super
    @controller = LinksController.new
    init_controller
  end
  
  def test_create
    login(:lion)
    node = secure!(Node) { nodes(:letter) }
    assert_nil node.find(:first, 'calendar')
    post 'create', 'node_id' => nodes_zip(:letter), 'link' => {'other_zip' => nodes_zip(:zena).to_s, 'role' => 'calendar', 'comment' => 'super icon'}
    assert_response :success
    node = assigns(:node)
    node = secure!(Node) { nodes(:letter) }
    assert calendar = node.find(:first, 'calendar')
    assert_equal nodes_id(:zena), calendar[:id]
    assert_equal 'super icon', calendar.l_comment
    assert_nil calendar.l_status
  end
  
  def test_show
    login(:lion)
    get 'show', 'id'=>links_id(:opening_in_art), 'node_id'=>nodes_zip(:art)
    assert_response :success
  end
end

