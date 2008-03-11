=begin
require File.dirname(__FILE__) + '/../test_helper'
require 'discussion_controller'

# Re-raise errors caught by the controller.
class DiscussionController; def rescue_action(e) raise e end; end

class DiscussionControllerTest < Test::Unit::TestCase
  def setup
    @controller = DiscussionController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
=end