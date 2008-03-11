=begin
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
  
  def test_login
    get 'new'
    assert_response :success
    assert_equal @response.rendered_file.split('/')[-3..-1], ["Node_login.html", "en", "main.erb"]
    assert_tag :tag=>"div", :attributes=>{:id=>'login_form'}
  end
  
  def test_create
    post 'create', :login=>'ant', :password=>'ant'
    assert_not_nil session[:user]
    assert_equal users_id(:ant), session[:user]
    assert_redirected_to user_home_url
  end
  
  def test_login_helper
    login(:ant)
    assert_equal users_id(:ant), session[:user]
  end
  
  def test_invalid_login
    post 'create', :login=>'ant', :password=>'tiger'
    assert_nil session[:user]
    assert_redirected_to '/login'
    assert_equal 'Invalid login or password.', flash[:error]
    
    post 'create', :login=>'ant', :password=>'bad'
    assert_nil session[:user]
    assert_equal 'Invalid login or password.', flash[:error]
    
    post 'create', :login=>'bad', :password=>'ant'
    assert_nil session[:user]
    assert_equal 'Invalid login or password.', flash[:error]
  end
  
  def test_logout
    get 'destroy'
    assert_nil session[:user]
    assert_redirected_to '/en'
  end
end
=end