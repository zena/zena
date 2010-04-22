require 'test_helper'

class ColumnsControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:columns)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create column" do
    assert_difference('Column.count') do
      post :create, :column => { }
    end

    assert_redirected_to column_path(assigns(:column))
  end

  test "should show column" do
    get :show, :id => columns(:one).to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => columns(:one).to_param
    assert_response :success
  end

  test "should update column" do
    put :update, :id => columns(:one).to_param, :column => { }
    assert_redirected_to column_path(assigns(:column))
  end

  test "should destroy column" do
    assert_difference('Column.count', -1) do
      delete :destroy, :id => columns(:one).to_param
    end

    assert_redirected_to columns_path
  end
end
