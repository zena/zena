require File.dirname(__FILE__) + '/../test_helper'
require 'user_controller'

# Re-raise errors caught by the controller.
class UserController; def rescue_action(e) raise e end; end

class UserControllerTest < Test::Unit::TestCase
  include ZenaTestController
  
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
