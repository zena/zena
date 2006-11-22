require File.dirname(__FILE__) + '/../test_helper'
require 'item_controller'

# Re-raise errors caught by the controller.
class ItemController; def rescue_action(e) raise e end; end

class ItemControllerTest < Test::Unit::TestCase

  include ZenaTestController
  def setup
    @controller = ItemController.new
    init_controller
  end
  
  
  def test_drive
    assert false, "test todo"
  end
end

#def test_can_manage
#  login(:tiger)
#  post 'manage', :id=>items_id(:status)
#  assert_tag :tag=>'div'
#  get 'manage', :id=>items_id(:status)
#  assert_tag :tag=>'div'
#end
#
#def test_cannot_manage
#  login(:ant)
#  post 'manage', :id=>items_id(:status)
#  assert_no_tag
#  get 'manage', :id=>items_id(:status)
#  assert_no_tag
#end