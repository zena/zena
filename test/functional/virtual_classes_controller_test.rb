require 'test_helper'

class VirtualClassesControllerTest < Zena::Controller::TestCase

  def setup
    super
    login(:lion)
  end

  test "should not have access to virtual classes if not admin" do
    login(:tiger)
    get :index
    assert_response :missing
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:virtual_classes)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create virtual class" do
    assert_difference('VirtualClass.count') do
      post :create, :virtual_class => { :name => 'Xkcd', :superclass => 'Section', :create_group_id => groups_id(:public) }
    end
    xkcd = assigns(:virtual_class)
    assert_equal "Xkcd",  xkcd.name
    assert_equal Section, xkcd.superclass
    assert_equal "NPSX",  xkcd.kpath
    assert_redirected_to virtual_class_path(assigns(:virtual_class))
  end

  test "should show virtual class" do
    get :show, :id => virtual_classes_id(:Letter)
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => virtual_classes_id(:Letter)
    assert_response :success
  end

  test "should update virtual class" do
    put :update, :id => virtual_classes_id(:Letter), :virtual_class => { :name => 'Brief'}
    brief = assigns(:virtual_class)
    assert_redirected_to virtual_class_path(brief)
    assert_equal 'Brief', brief.name
    assert_equal "NNB",  brief.kpath
  end

  test "should destroy virtual class" do
    assert_difference('VirtualClass.count', -1) do
      delete :destroy, :id => virtual_classes_id(:Letter)
    end
    assert_redirected_to virtual_classes_path
  end

  context 'importing virtual class definitions' do
    should 'create virtual_classes' do
      assert_difference('VirtualClass.count', 3) do
        post :import, :attachment => uploaded_fixture('vclasses.yml', 'text/yaml')
      end
      list = assigns(:virtual_classes)
    end
  end
end