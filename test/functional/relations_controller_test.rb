require File.dirname(__FILE__) + '/../test_helper'
require 'relations_controller'

# Re-raise errors caught by the controller.
class RelationsController; def rescue_action(e) raise e end; end

class RelationsControllerTest < Test::Unit::TestCase
  fixtures :relations

  def setup
    @controller = RelationsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_should_get_index
    get :index
    assert_response :success
    assert assigns(:relations)
  end

  def test_should_get_new
    get :new
    assert_response :success
  end
  
  def test_should_create_relation
    old_count = Relation.count
    post :create, :relation => { }
    assert_equal old_count+1, Relation.count
    
    assert_redirected_to relation_path(assigns(:relation))
  end

  def test_should_show_relation
    get :show, :id => 1
    assert_response :success
  end

  def test_should_get_edit
    get :edit, :id => 1
    assert_response :success
  end
  
  def test_should_update_relation
    put :update, :id => 1, :relation => { }
    assert_redirected_to relation_path(assigns(:relation))
  end
  
  def test_should_destroy_relation
    old_count = Relation.count
    delete :destroy, :id => 1
    assert_equal old_count-1, Relation.count
    
    assert_redirected_to relations_path
  end
end
