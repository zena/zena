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
    @visitor = admin
    root = secure(Node) { Node.find(site[:root_id]) }
    assert_equal Zena::Status[:pub], root.v_status
    assert_equal Zena::Status[:pub], root.max_status
    assert Time.now >= root.publish_from
    @visitor = site.anon
    root = secure(Node) { Node.find(site[:root_id]) }
    assert_kind_of Project, root
    assert_equal 'super', root.v_title
    assert_nothing_raised { Node.next_zip(site[:id]) }
    
    admin = secure(User) { User.find(admin[:id]) }
    assert_kind_of Contact, admin.contact
    anon  = secure(User) { User.find(site.anon[:id]) }
    assert_kind_of Contact, anon.contact
    
    skin  = secure(Skin) { Skin.find_by_name('default') }
    assert_kind_of Skin, skin
    node = secure(Node)  { Node.find_by_parent_id_and_name(skin[:id], 'Project') }
    assert_kind_of Template, node
  end
  
  def test_create_site_bad_name
    site = Site.create_for_host('../evil.com', 'zoomzoom')
    assert site.new_record?
    assert site.errors[:host]
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
  
  def test_monolingual
    site = sites(:zena)
    assert !site.monolingual, "Multi lang site"
    site.monolingual = true
    assert site.save, "Can save"
    assert site.monolingual, "Mono lang site"
  end
  
  def test_protected_fields
    site = sites(:zena)
    site.update_attributes(:id=>sites_id(:ocean), :root_id=>11, :host=>'example.com')
    site = sites(:zena) # reload
    assert_equal sites_id(:zena), site[:id]
    assert_equal nodes_id(:zena), site[:root_id]
    assert_equal 'test.host', site[:host]
  end
  
  def test_lang_list
    site = sites(:zena)
    site.languages = "en,fr"
    assert_equal ['en', 'fr'], site.lang_list
    site.languages = "en,fr, ru , es"
    assert_equal ['en', 'fr', 'ru', 'es'], site.lang_list
  end
end
