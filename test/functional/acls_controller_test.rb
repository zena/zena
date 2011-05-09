require 'test_helper'

class AclsControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:acls)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create acl" do
    assert_difference('Acl.count') do
      post :create, :acl => { }
    end

    assert_redirected_to acl_path(assigns(:acl))
  end

  test "should show acl" do
    get :show, :id => acls(:one).to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => acls(:one).to_param
    assert_response :success
  end

  test "should update acl" do
    put :update, :id => acls(:one).to_param, :acl => { }
    assert_redirected_to acl_path(assigns(:acl))
  end

  test "should destroy acl" do
    assert_difference('Acl.count', -1) do
      delete :destroy, :id => acls(:one).to_param
    end

    assert_redirected_to acls_path
  end
end
