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
    node = secure!(Node) { nodes(:people) }
    assert_nil node.find(:first, 'icon')
    post 'create', 'node_id' => nodes_zip(:people), 'link' => {'other_zip' => 'bird', 'role' => 'icon', 'comment' => 'super icon'}
    assert_response :success
    node = secure!(Node) { nodes(:people) }
    assert icon = node.find(:first, 'icon')
    assert_equal nodes_id(:bird_jpg), icon[:id]
    assert_equal 'super icon', icon.l_comment
    assert_nil icon.l_status
  end
end

