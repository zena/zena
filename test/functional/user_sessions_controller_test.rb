require 'test_helper'

class UserSessionsControllerTest < Zena::Controller::TestCase

  context "Controller actions" do

    should "get login page" do
      get :new
      assert_not_nil assigns(:node)
    end

    should "create a session" do
      #Site.connection.execute "UPDATE sites SET authentication = 1 WHERE id = #{sites_id(:zena)}"
      post 'create', :login=>'ant', :password=>'ant'
      assert assigns(:user_session).persisting?
      assert_response 302
    end

    should "redirect to login page in login failed" do
      post 'create', :login=>'ant', :password=>'boom'
      assert !assigns(:user_session).persisting?
      assert_redirected_to login_url
    end

  end

  context "with login Test Case" do

    setup do
      login('su')
    end

    should "visitor be accessible" do
      assert_equal 'su', visitor.login
    end

    should "site be accessible" do
      assert_equal 'zena', $_test_site
    end

    should "check if visitor is admin" do
      assert visitor.is_admin?
    end

  end

end

