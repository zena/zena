require 'test_helper'

class RelationsControllerTest < Zena::Controller::TestCase

  def setup
    super
    login(:lion)
  end

  def test_should_get_index
    get :index
    assert_response :success
    assert assigns(:relations)
  end

  def test_should_not_find_index_if_not_admin
    login(:tiger)
    get :index
    assert_response :missing
  end

  def test_should_get_new
    get :new
    assert_response :success
  end

  def test_should_create_relation
    assert_difference('Relation.count', 1) do
      post :create, :relation => {:source_role => 'wife', :target_role => 'husband'}
    end
    assert_redirected_to relation_path(assigns(:relation))
  end

  def test_should_show_relation
    get :show, :id => relations_id(:node_has_tags)
    assert_response :success
  end

  def test_should_get_edit
    get :edit, :id => relations_id(:node_has_tags)
    assert_response :success
  end

  def test_should_update_relation
    put :update, :id => relations_id(:node_has_tags), :relation => {:source_role => 'taga' }
    assert_redirected_to relation_path(assigns(:relation))
  end

  def test_should_destroy_relation
    assert_difference('Relation.count', -1) do
      delete :destroy, :id => relations_id(:node_has_tags)
    end
    assert_redirected_to relations_path
  end
end