require File.dirname(__FILE__) + '/../test_helper'
require 'node_controller'

# Re-raise errors caught by the controller.
class NodeController
  def rescue_action(e); raise e; end
end

class TestNodeController < NodeController
  include NodeHelper
end

class NodeControllerTest < ZenaTestController

  def setup
    super
    @controller = NodeController.new
    init_controller
  end
  
  def test_form_tabs
    @controller = TestNodeController.new
    init_controller
    page = @controller.send(:secure, Node) { Node.find(nodes_id(:status))    }
    @controller.instance_variable_set(:@node, page)
    assert_equal [["drive", "drive"], ["links", "links"], ["help", "help"]], @controller.send(:form_tabs)
  end
  
  def test_popup_page_not_found
    get 'drive', :id=>99
    assert_redirected_to :controller => 'node', :action=>'not_found'
    get 'not_found'
    assert_template 'node/not_found'
  end
end
