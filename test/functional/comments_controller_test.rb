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
    post 'create', 'node_id'=>nodes_zip(:status), 'comment'=>{'title'=>'blowe', 'text' => 'I do not know..'}
    assert_response :redirect
    assert_redirected_to zen_path(nodes(:status))
    comment = assigns['comment']
    assert !comment.new_record?
  end
  
  def test_update
    login(:tiger)
    put 'update', 'id'=>comments_id(:tiger_says_inside), 'comment'=>{'title'=>'hahaha', 'text' => 'new text'}
    assert_response :redirect
    assert_redirected_to zen_path(nodes(:status))
    comment = assigns['comment']
    assert_equal comments_id(:tiger_says_inside), comment[:id]
    comment = comments(:tiger_says_inside) # reload
    assert_equal 'hahaha', comment[:title]
    assert_equal 'new text', comment[:text]
  end
  
  def test_cannot_update
    login(:ant)
    put 'update', 'id'=>comments_id(:tiger_says_inside), 'comment'=>{'title'=>'other title', 'text' => 'other text'}
    assert_response :redirect
    assert_redirected_to zen_path(nodes(:status))
    comment = assigns['comment']
    assert !comment.new_record?
    assert_equal 'you do not have the rights to do this', comment.errors[:base]
    comment = comments(:tiger_says_inside)
    assert_equal 'We could not do better then this. I *really* mean that. Look at the "":20.', comment[:text]
  end
  
  def test_index
    login(:anon)
    get 'index'
    assert_response :not_found
    login(:lion)
    get 'index'
    assert_response :success
  end
  
  def test_remove
    login(:lion)
    assert_equal Zena::Status[:prop], comments(:public_spam_in_en).status
    post "remove", "id"=>comments_id(:public_spam_in_en)
    assert_response :success
    assert_equal Zena::Status[:rem], comments(:public_spam_in_en).status
  end
  
  def test_bin
  end
  # TODO: test rjs...
end