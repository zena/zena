require File.dirname(__FILE__) + '/../test_helper'
require 'dataentries_controller'

# Re-raise errors caught by the controller.
class DataentriesController; def rescue_action(e) raise e end; end

class DataentriesControllerTest < Test::Unit::TestCase
  def setup
    @controller = DataentriesController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
