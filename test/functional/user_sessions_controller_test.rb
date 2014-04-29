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
    
    context 'on failure' do
      should "redirect to login page" do
        post 'create', :login=>'ant', :password=>'boom'
        assert !assigns(:user_session).persisting?
        assert_redirected_to login_path
      end
      
      should 'increment user login_attempt_count' do
        assert_nil users(:ant).login_attempt_count
        post 'create', :login=>'ant', :password=>'boom'
        assert_equal 1, users(:ant).login_attempt_count
      end
      
      should 'set attempt datetime' do
        a = Time.now.utc.to_i
        assert_nil users(:ant).login_attempted_at
        post 'create', :login=>'ant', :password=>'boom'
        b = Time.now.utc.to_i
        assert a <= users(:ant).login_attempted_at.to_i
        assert b >= users(:ant).login_attempted_at.to_i
      end
    end
    
    context 'with a large attempt count' do
      setup do
        Zena::Db.set_attribute(users(:ant), 'login_attempt_count', 10)
        Zena::Db.set_attribute(users(:ant), 'login_attempted_at', Time.now.utc)
      end
      
      should 'refuse login' do
        post 'create', :login => 'ant', :password => 'ant'
        assert_redirected_to login_path
        assert_equal 'You need to wait 0h 17m 4s before any new attempt (10 failed attempts).', flash[:error]
      end
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
    
    should 'redirect to home on login' do
      get :new
      assert_redirected_to 'oo'
    end

  end

  context 'a visitor on the wrong site' do
    setup do
      @request.host = 'ocean.host'
    end

    should 'not be allowed to login' do
      post 'create', :login => 'ant', :password => 'ant'
      assert !assigns(:user_session)
      assert_redirected_to login_path
    end
  end

end

