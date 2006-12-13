require File.dirname(__FILE__) + '/../test_helper'
require 'link_controller'

# Re-raise errors caught by the controller.
class LinkController; def rescue_action(e) raise e end; end

class LinkControllerTest < Test::Unit::TestCase
  def setup
    @controller = LinkController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
