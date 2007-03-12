require File.dirname(__FILE__) + '/../test_helper'

class SiteTest < ZenaTestUnit

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
    assert_equal "#{RAILS_ROOT}/sites/test.host/data", site.data_path
    site[:data_path] = "/var/data/test.host"
    assert_equal "/var/data/test.host", site.data_path
    site = sites(:ocean)
    assert_equal "#{RAILS_ROOT}/sites/ocean.host/data", site.data_path
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
