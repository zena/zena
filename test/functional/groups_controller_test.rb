require 'test_helper'

class GroupsControllerTest < Zena::Controller::TestCase

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
    assert group.errors[:name] #.any?
  end
  
  def test_update_name_public_group
    login(:lion)
    put 'update', :id => groups_id(:public), :group=>{:name=>'wowo'}
    assert_redirected_to :action => 'show'
    group = assigns['group']
    assert group.errors.empty?
    assert_equal 'wowo', group.name
  end
  
  def test_cannot_update_users_in_public_group
    login(:lion)
    put 'update', :id => groups_id(:public), :group=>{:user_ids=>[users_id(:ant)]}
    assert_redirected_to :action => 'show'
    group = assigns['group']
    assert group.errors.empty?
    assert_equal [users_id(:ant), users_id(:anon), users_id(:tiger), users_id(:lion)].sort, group.users.map{|u| u[:id]}.sort
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
  
  def test_destroy
    login(:lion)
    delete 'destroy', :id => groups_id(:managers)
    assert_template 'edit'
    group = assigns['group']
    assert group.errors[:base] #.any?
    
    post 'create', :group=>{:name=>'stupid', :user_ids=>[users_id(:ant), users_id(:tiger)]}
    group = assigns['group']
    delete 'destroy', :id => group[:id]
    assert_redirected_to :action => 'index'
    assert_nil Group.find(:first, :conditions => "id = #{group[:id]}")
  end
end
