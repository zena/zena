require File.dirname(__FILE__) + '/../test_helper'

class SiteTest < ZenaTestUnit
  
  def test_create_site
    site = nil
    assert_nothing_raised { site = Site.create_for_host('super.host', 'secret') }
    site = Site.find(site[:id]) # reload
    assert_equal "Anonymous User", site.anon.fullname
    assert_not_equal users(:anon), site.anon[:id]
    assert admin = User.login('admin', 'secret', site), "Admin user can login"
    assert_equal 3, admin.group_ids.size
    login(:anon)
    root = secure(Node) { Node.find(site[:root_id]) }
    assert_kind_of Node, root
    assert_equal 'super', root.v_title
  end

  def test_public_path
    site = sites(:zena)
    assert_equal "/test.host/public", site.public_path
    site = sites(:ocean)
    assert_equal "/ocean.host/public", site.public_path
  end
  
  def test_data_path
    site = sites(:zena)
    assert_equal "/test.host/data", site.data_path
    site = sites(:ocean)
    assert_equal "/ocean.host/data", site.data_path
  end
  
  def test_anonymous
    site = sites(:zena)
    anon = site.anon
    assert_kind_of User, anon
    assert anon.is_anon?
    assert_equal 'Anonymous', anon.first_name
    assert_equal users_id(:anon), anon[:id]
    anon.site = site
    assert anon.is_anon?
    
    site = sites(:ocean)
    anon = site.anon
    assert_equal 'Miss', anon.first_name
    assert_equal users_id(:incognito), anon[:id]
    anon.site = site
    assert anon.is_anon?
  end
  
  def test_su
    site = sites(:zena)
    su = site.su
    assert_kind_of User, su
    assert_equal 'Super', su.first_name
    assert_equal users_id(:su), su[:id]
    su.site = site
    assert su.is_su?
    
    site = sites(:ocean)
    su = site.su
    assert_kind_of User, su
    assert_equal 'Hyper', su.first_name
    assert_equal users_id(:other_su), su[:id]
    su.site = site
    assert su.is_su?
  end
  
  def test_public_group
    site = sites(:zena)
    grp = site.public_group
    assert_kind_of Group, grp
    assert_equal groups_id(:public), grp[:id]
    
    site = sites(:ocean)
    grp = site.public_group
    assert_kind_of Group, grp
    assert_equal groups_id(:pub_ocean), grp[:id]
  end
  
  def test_site_group
    site = sites(:zena)
    grp = site.site_group
    assert_kind_of Group, grp
    assert_equal groups_id(:site), grp[:id]
    
    site = sites(:ocean)
    grp = site.site_group
    assert_kind_of Group, grp
    assert_equal groups_id(:aqua), grp[:id]
  end
  
  def test_admin_group
    site = sites(:zena)
    grp = site.admin_group
    assert_kind_of Group, grp
    assert_equal groups_id(:admin), grp[:id]
    
    site = sites(:ocean)
    grp = site.admin_group
    assert_kind_of Group, grp
    assert_equal groups_id(:masters), grp[:id]
  end
end
