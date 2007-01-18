require File.dirname(__FILE__) + '/../test_helper'
require 'node_controller'

# Re-raise errors caught by the controller.
class NodeController; def rescue_action(e) raise e end; end

class NodeControllerTest < Test::Unit::TestCase

  include ZenaTestController
  def setup
    @controller = NodeController.new
    init_controller
  end
  
  
  def test_drive
    assert false, "test todo"
  end
end

#def test_can_manage
#  login(:tiger)
#  post 'manage', :id=>nodes_id(:status)
#  assert_tag :tag=>'div'
#  get 'manage', :id=>nodes_id(:status)
#  assert_tag :tag=>'div'
#end
#
#def test_cannot_manage
#  login(:ant)
#  post 'manage', :id=>nodes_id(:status)
#  assert_no_tag
#  get 'manage', :id=>nodes_id(:status)
#  assert_no_tag
#end