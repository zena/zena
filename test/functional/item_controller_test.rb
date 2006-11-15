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
