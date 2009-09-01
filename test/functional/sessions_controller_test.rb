=begin
TODO: fix with AUTHLOGIC !




require 'test_helper'
require 'session_controller'

# Re-raise errors caught by the controller.
class SessionsController; def rescue_action(e) raise e end; end

class SessionsControllerTest < ZenaTestController
  
  def setup
    super
    @controller = SessionsController.new
    init_controller
  end
  
  def test_render_invalid_login
    Version.connection.execute "UPDATE #{Version.table_name} SET text = 'empty' WHERE id = #{versions_id(:Node_login_zafu_en)}"
    without_files('test.host/zafu') do
      get 'new'
      assert_response :success
      assert_equal ["zafu", "default", "Node-+login", "en", "_main.erb"], @response.rendered_file.split('/')[-5..-1]
      assert_match %r{Using default '\+login' template}, @response.body
      assert_no_match %r{empty}, @response.body
    end
  end
  
  def test_login
    get 'new'
    assert_response :success
    assert_equal ["zafu", "default", "Node-+login", "en", "_main.erb"], @response.rendered_file.split('/')[-5..-1]
    assert_tag :tag=>"div", :attributes=>{:id=>'login_form'}
  end
  
  def test_create
    post 'create', :login=>'ant', :password=>'ant'
    assert_not_nil session[:user]
    assert_equal users_id(:ant), session[:user]
    assert_redirected_to user_path(users(:ant))
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