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
  
  def test_update_preferences
    login(:lion)
    put 'update', 'id' => users_id(:lion), 'user'=>{'name'=>'Leo Verneyi', 'lang'=>'en', 'time_zone'=>'Africa/Algiers', 'first_name'=>'Panthera', 'login'=>'lion', 'email'=>'lion@zenadmin.info'}
    assert_response :success
    user = assigns['user']
    assert_equal 'Africa/Algiers', user[:time_zone]
  end
end