require File.dirname(__FILE__) + '/../test_helper'

class SiteTest < ZenaTestUnit
  
  def test_create_site
    site = nil
    assert_nothing_raised { site = Site.create_for_host('super.host', 'secret') }
    site = Site.find(site[:id]) # reload
    assert_equal "Anonymous User", site.anon.fullname
    assert_not_equal users(:anon), site.anon[:id]
    assert admin = User.login('admin', 'secret', site), "Admin user can login"
    assert_equal 2, admin.group_ids
  end

  def test_public_path
    site = sites(:default)
    assert_equal "#{RAILS_ROOT}/sites/test.host/public", site.public_path
    site[:public_path] = "/var/www/test.host"
    assert_equal "/var/www/test.host", site.public_path
    site = sites(:ocean)
    assert_equal "#{RAILS_ROOT}/sites/ocean.host/public", site.public_path
  end
  
  def test_data_path
    site = sites(:default)
    assert_equal "/test.host/data", site.data_path
    site = sites(:ocean)
    assert_equal "/ocean.host/data", site.data_path
  end
  
  def test_anonymous
    site = sites(:default)
    anon = site.anon
    assert_kind_of User, anon
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
    site = sites(:default)
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
end
