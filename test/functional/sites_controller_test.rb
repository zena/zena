require File.dirname(__FILE__) + '/../test_helper'
require 'sites_controller'

# Re-raise errors caught by the controller.
class SitesController; def rescue_action(e) raise e end; end

class SitesControllerTest < Test::Unit::TestCase
  def setup
    @controller = SitesController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
