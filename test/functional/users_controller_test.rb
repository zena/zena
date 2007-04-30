require File.dirname(__FILE__) + '/../test_helper'
require 'users_controller'

# Re-raise errors caught by the controller.
class UsersController; def rescue_action(e) raise e end; end

class UsersControllerTest < ZenaTestController
  
  def setup
    super
    @controller = UsersController.new
    init_controller
  end

  def test_check_is_admin_fail
    get 'show', :id=>4
    assert_redirected_to :controller=>'main', :action=>'not_found'
    login(:ant)
    get 'show', :id=>4
    assert_redirected_to :controller=>'main', :action=>'not_found'
  end
  
  def test_check_is_admin_ok
    login(:lion)
    get 'show', :id=>4
    assert_response :success
    assert_template 'show'
  end
  
  def test_list
    login(:ant)
    get 'list'
    assert_redirected_to :controller=>'main', :action=>'not_found'
    login(:lion)
    get 'list'
    assert_response :success
    assert_equal 5, assigns(:users).size
  end
  
  def test_home
    login(:lion)
    get 'home'
    assert_response :success
  end
  
  def test_admin_layout
    #without_files('app/views/templates/compiled/wiki') do
      login(:lion)
      get 'home'
      assert_tag :ul, :attributes=>{:class=>'actions'}
      assert_no_tag :div, :attributes=>{:class=>'wiki_layout'}
      Node.connection.execute "UPDATE nodes SET skin = 'wiki' WHERE id = 3"
      login(:ant)
      get 'home'
      assert_tag :ul, :attributes=>{:class=>'actions'}
      assert_tag :div, :attributes=>{:class=>'wiki_layout'}
    #end
  end
end
