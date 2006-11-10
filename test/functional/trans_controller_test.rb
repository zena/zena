require File.dirname(__FILE__) + '/../test_helper'
require 'trans_controller'

# Re-raise errors caught by the controller.
class TransController; def rescue_action(e) raise e end; end

class TransControllerTest < Test::Unit::TestCase
  def setup
    @controller = TransController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
