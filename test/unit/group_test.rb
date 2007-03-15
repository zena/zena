require File.dirname(__FILE__) + '/../test_helper'

class GroupTest < ZenaTestUnit
  
  def test_public_group
    login(:ant)
    grp = secure(Group) { groups(:public) }
    assert grp.public_group?, "'public' is the public group."
    grp = secure(Group) { groups(:site) }
    assert !grp.public_group?, "'site' is not the public group."
    
    login(:whale)
    grp = secure(Group) { groups(:public) }
    assert !grp.public_group?, "'public' is not the public group for 'ocean.host'."
  end
  
  def test_admin_group
    login(:ant)
    grp = secure(Group) { groups(:admin) }
    assert grp.admin_group?, "'admin' is the admin group."
    grp = secure(Group) { groups(:site) }
    assert !grp.admin_group?, "'site' is not the admin group."
    
    login(:whale)
    grp = secure(Group) { groups(:admin) }
    assert !grp.admin_group?, "'admin' is not the admin group for 'ocean.host'."
  end
  
  def test_site_group
    login(:ant)
    grp = secure(Group) { groups(:site) }
    assert grp.site_group?, "'site' is the site group."
    grp = secure(Group) { groups(:admin) }
    assert !grp.site_group?, "'admin' is not the site group."
    
    login(:whale)
    grp = secure(Group) { groups(:site) }
    assert !grp.site_group?, "'site' is not the site group for 'ocean.host'."
  end
  
  def test_user_ids
    sitegrp = groups(:site)
    assert_equal [users_id(:ant),users_id(:lion),users_id(:tiger)], sitegrp.user_ids
  end
  
  def test_users_password_nil
    sitegrp = groups(:site)
    users = sitegrp.users
    assert_equal 3, users.size
    assert_nil users[0].password
    assert_nil users[1].password
    assert_nil users[2].password
  end
  
  def test_dont_destroy_public_or_admin
    login(:lion)
    grp = secure(Group) { groups(:public) }
    assert_raise(Zena::AccessViolation) { grp.destroy }
    grp = secure(Group) { groups(:admin) }
    assert_raise(Zena::AccessViolation) { grp.destroy }
    grp = secure(Group) { groups(:site) }
    assert_raise(Zena::AccessViolation) { grp.destroy }
  end
  
  def test_create_and_destroy
    login(:lion)
    grp = secure(Group) { Group.create(:name=>'test') }
    assert !grp.new_record?, "Not a new record"
    assert_equal sites(:zena)[:id], grp[:site_id]
    assert grp.destroy, "Can destroy group"
  end
  
  # TODO: test secure (group can be created in this site...)
  def test_valid_group
    self[:site_id] = visitor.site[:id]
  end
  
end
