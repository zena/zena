require File.dirname(__FILE__) + '/../test_helper'
require 'groups_controller'

# Re-raise errors caught by the controller.
class GroupsController; def rescue_action(e) raise e end; end

class GroupsControllerTest < ZenaTestController
  
  def setup
    super
    @controller = GroupsController.new
    init_controller
  end

  def test_create_with_users
    login(:lion)
    post 'create', :group=>{:name=>'stupid', :user_ids=>[users_id(:ant), users_id(:tiger)]}
    assert_response :success
    group = assigns['group']
    assert_kind_of Group, group
    assert !group.new_record?, "Not a new record"
    assert_equal [users_id(:ant), users_id(:tiger)], group.users.map{|u| u[:id]}
  end
  
  
  def test_create_without_empty_users
    login(:lion)
    post 'create', :group=>{:name=>'stupid', :user_ids=>[""]}
    assert_response :success
    group = assigns['group']
    assert_kind_of Group, group
    assert !group.new_record?, "Not a new record"
    assert_equal [], group.users
  end
  
  def test_create_without_users
    login(:lion)
    post 'create', :group=>{:name=>'stupid'}
    assert_response :success
    group = assigns['group']
    assert_kind_of Group, group
    assert !group.new_record?, "Not a new record"
    assert_equal [], group.users
  end
  
  def test_update_name
    login(:lion)
    put 'update', :id => groups_id(:workers), :group=>{:name=>'wowo'}
    assert_redirected_to :action => 'show'
    group = assigns['group']
    assert group.errors.empty?
    assert_equal 'wowo', group.name
  end
  
  def test_update_same_name
    login(:lion)
    put 'update', :id => groups_id(:workers), :group=>{:name=>'admin'}
    assert_template 'edit'
    group = assigns['group']
    assert group.errors[:name]
  end
  
  def test_update_name_public_group
    login(:lion)
    put 'update', :id => groups_id(:public), :group=>{:name=>'wowo'}
    assert_redirected_to :action => 'show'
    group = assigns['group']
    assert group.errors.empty?
    assert_equal 'wowo', group.name
  end
  
  def test_edit
    login(:lion)
    get 'edit', :id => groups_id(:public)
    assert_response :success
    assert_template 'edit'
    assert_equal groups_id(:public), assigns['group'][:id]
  end
  
  def test_index
    login(:lion)
    get 'index'
    assert_response :success
  end
  
  def test_show
    login(:lion)
    get 'show', :id => groups_id(:workers)
    assert_response :success
  end
  
  def test_show_not_admin
    get 'show', :id => groups_id(:workers)
    assert_response 404
  end
end
