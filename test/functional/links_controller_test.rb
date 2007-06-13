require File.dirname(__FILE__) + '/../test_helper'
require 'links_controller'

# Re-raise errors caught by the controller.
class LinksController; def rescue_action(e) raise e end; end

class LinksControllerTest < Test::Unit::TestCase
  fixtures :links

  def setup
    @controller = LinksController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_should_get_index
    get :index
    assert_response :success
    assert assigns(:links)
  end

  def test_should_get_new
    get :new
    assert_response :success
  end
  
  def test_should_create_link
    old_count = Link.count
    post :create, :link => { }
    assert_equal old_count+1, Link.count
    
    assert_redirected_to link_path(assigns(:link))
  end

  def test_should_show_link
    get :show, :id => 1
    assert_response :success
  end

  def test_should_get_edit
    get :edit, :id => 1
    assert_response :success
  end
  
  def test_should_update_link
    put :update, :id => 1, :link => { }
    assert_redirected_to link_path(assigns(:link))
  end
  
  def test_should_destroy_link
    old_count = Link.count
    delete :destroy, :id => 1
    assert_equal old_count-1, Link.count
    
    assert_redirected_to links_path
  end
end
