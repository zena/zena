require File.dirname(__FILE__) + '/../test_helper'
require 'nodes_controller'

# Re-raise errors caught by the controller.
class NodesController
  def rescue_action(e); raise e; end
end

class TestNodeController < NodesController
  include NodesHelper
end

class NodesControllerTest < ZenaTestController

  def setup
    super
    @controller = NodesController.new
    init_controller
  end
  
  def test_import_archive
    preserving_files('test.host/data') do
      login(:tiger)
      post 'import', :archive => uploaded_archive('import.tgz'), :id => nodes_zip(:status)
      assert_response :success
      assert_template 'import'
    end
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
  
  # test edit_... mode only if can_edit?
  
  def test_import
    assert false
  end
end
