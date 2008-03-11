=begin
require File.dirname(__FILE__) + '/../test_helper'
require 'comment_controller'

# Re-raise errors caught by the controller.
class CommentController
  def rescue_action(e)
    raise e
  end
end

class CommentControllerTest < ZenaTestController

  def setup
    super
    @controller = CommentController.new
    init_controller
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
=end