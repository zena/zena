require File.dirname(__FILE__) + '/../test_helper'
require 'comments_controller'

# Re-raise errors caught by the controller.
class CommentsController; def rescue_action(e) raise e end; end

class CommentsControllerTest < ZenaTestController
  
  def setup
    super
    @controller = CommentsController.new
    init_controller
  end
  
  def test_create
    login(:lion)
    post 'create', "node_id"=>nodes_zip(:status), "comment"=>{"title"=>"blowe", 'text' => 'I do not know..'}
    assert_response :redirect
    assert_redirected_to zen_path(nodes(:status))
    comment = assigns['comment']
    assert !comment.new_record?
  end
  
  # TODO: test rjs...
end