require File.dirname(__FILE__) + '/../test_helper'
require 'session_controller'

# Re-raise errors caught by the controller.
class SessionController; def rescue_action(e) raise e end; end

class SessionControllerTest < ZenaTestController
  
  def setup
    super
    @controller = SessionController.new
    init_controller
  end
  
  def test_get_login
    get 'new'
    assert_response :success
    assert_template 'new'
    assert_tag :tag=>"div", :attributes=>{:id=>'please_login'}
  end
  
  def test_post_login
    post 'login', :user=>{:login=>'ant', :password=>'ant'}
    assert_not_nil session[:user]
    assert_equal users_id(:ant), session[:user][:id]
    assert_equal addresses(:ant).fullname, session[:user][:fullname]
    assert_equal [1,3], addresses(:ant).group_ids
    assert_equal [1,3], session[:user][:groups]
    assert_redirected_to user_home_url
  end
  
  def test_login_helper
    login
    assert_equal users_id(:ant), session[:user][:id]
  end
  
  def test_invalid_login
    post 'login', :user=>{:login=>'ant', :password=>'tiger'}
    assert_nil session[:user]
    assert_template 'login'
    assert_equal 'Invalid login or password', flash[:error]
    
    post 'login', :user=>{:login=>'ant', :password=>'bad'}
    assert_nil session[:user]
    assert_template 'login'
    assert_equal 'Invalid login or password', flash[:error]
    
    post 'login', :user=>{:login=>'bad', :password=>'ant'}
    assert_nil session[:user]
    assert_template 'login'
    assert_equal 'Invalid login or password', flash[:error]
  end
  
  def test_logout
    get 'logout'
    assert_nil session[:user]
    assert_redirected_to login_url
  end
end
