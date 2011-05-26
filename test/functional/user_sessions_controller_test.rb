require 'test_helper'

class UserSessionsControllerTest < Zena::Controller::TestCase

  context "Controller actions" do

    should "get login page" do
      get :new
      assert_not_nil assigns(:node)
    end

    should "create a session" do
      post 'create', :login=>'ant', :password=>'ant'
      assert assigns(:user_session).persisting?
      assert_response 302
    end

    should "redirect to login page if login failed" do
      post 'create', :login=>'ant', :password=>'boom'
      assert !assigns(:user_session).persisting?
      assert_redirected_to login_path
    end

  end

  context "with login Test Case" do

    setup do
      login('lion')
    end

    should "visitor be accessible" do
      assert_equal 'lion', visitor.login
    end

    should "site be accessible" do
      assert_equal 'zena', $_test_site
    end

    should "check if visitor is admin" do
      assert visitor.is_admin?
    end

  end

  context 'a visitor on the wrong site' do
    setup do
      @request.host = 'ocean.host'
    end

    should 'not be allowed to login' do
      post 'create', :login => 'ant', :password => 'ant'
      assert !assigns(:user_session).persisting?
      assert_redirected_to login_path
    end
  end

end

