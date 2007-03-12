require File.dirname(__FILE__) + '/../test_helper'
require 'group_controller'

# Re-raise errors caught by the controller.
class GroupController; def rescue_action(e) raise e end; end

class GroupControllerTest < ZenaTestController
  
  def setup
    super
    @controller = UserController.new
    init_controller
  end


  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
