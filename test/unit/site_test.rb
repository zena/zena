require File.dirname(__FILE__) + '/../test_helper'

class SiteTest < ZenaTestUnit
  
  def test_create_site
    site = nil
    assert_nothing_raised { site = Site.create_for_host('super.host', 'secret') }
    site = Site.find(site[:id]) # reload
    assert_equal "Anonymous User", site.anon.fullname
    assert_not_equal users(:anon), site.anon[:id]
    assert admin = User.login('admin', 'secret', 'super.host'), "Admin user can login"

    assert_equal 3, admin.group_ids.size
    root = secure!(Node) { Node.find(site[:root_id]) }
    assert_equal Zena::Status[:pub], root.v_status
    assert_equal Zena::Status[:pub], root.max_status
    assert_equal 'default', root.skin
    
    assert Time.now >= root.publish_from
    User.make_visitor(:host => 'super.host') # anonymous
    
    root = secure!(Node) { Node.find(site[:root_id]) }
    assert_kind_of Project, root
    assert_equal 'super', root.v_title
    assert_equal Zena::Status[:pub], root.max_status
    assert_nothing_raised { Node.next_zip(site[:id]) }
    
    admin = secure!(User) { User.find(admin[:id]) }
    assert_kind_of Contact, admin.contact
    anon  = secure!(User) { User.find(site.anon[:id]) }
    assert_kind_of Contact, anon.contact
    
    skin  = secure!(Skin) { Skin.find_by_name('default') }
    assert_kind_of Skin, skin
    assert_equal 'default', skin.skin
  end
  
  def test_create_site_with_opts
    site = nil
    assert_nothing_raised { site = Site.create_for_host('super.host', 'secret', :default_lang => 'fr') }
    site = Site.find(site[:id]) # reload
    assert_equal ['fr'], site.lang_list
    assert_equal 'fr', site.default_lang
    assert_equal 'fr', site.anon.lang
  end
  
  def test_create_site_with_opts
    with_caching do
      site = nil
      assert_nothing_raised { site = Site.create_for_host('super.host', 'secret', :default_lang => 'fr') }
      site = Site.find(site[:id]) # reload
      assert_equal ['fr'], site.lang_list
      assert_equal 'fr', site.default_lang
      assert_equal 'fr', site.anon.lang
    end
  end
  
  def test_create_site_with_opts_bad_lang
    site = nil
    assert_nothing_raised { site = Site.create_for_host('super.host', 'secret', :default_lang => 'en_US') }
    site = Site.find(site[:id]) # reload
    assert_equal ['en'], site.lang_list
    assert_equal 'en', site.default_lang
    assert_equal 'en', site.anon.lang
  end
  
  def test_create_site_bad_name
    site = Site.create_for_host('../evil.com', 'zoomzoom')
    assert site.new_record?
    assert site.errors[:host]
  end
  
  def test_valid_site
    login(:lion)
    site = sites(:zena)
    assert ! site.update_attributes(:languages => "french, en")
    assert_equal "invalid languages", site.errors[:languages]
    site = sites(:zena)
    assert ! site.update_attributes(:languages => "fr,en", :default_lang=>'')
    assert_equal "invalid default language", site.errors[:default_lang]
    site = sites(:zena)
    assert ! site.update_attributes(:languages => "fr,en", :default_lang=>'french')
    assert_equal "invalid default language", site.errors[:default_lang]
    site = sites(:zena)
    assert site.update_attributes(:languages => "fr ,en, ru ", :default_lang=>'ru')
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
  
  def test_zafu_path
    site = sites(:zena)
    assert_equal "/test.host/zafu", site.zafu_path
    site = sites(:ocean)
    assert_equal "/ocean.host/zafu", site.zafu_path
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
    
    login(:incognito)
    site = sites(:ocean)
    anon = site.anon
    assert_equal 'Miss', anon.first_name
    assert_equal users_id(:incognito), anon[:id]
    anon.site = site
    assert anon.is_anon?
  end
  
  def test_su
    login(:anon)
    site = sites(:zena)
    su = site.su
    assert_kind_of User, su
    assert_equal 'Super', su.first_name
    assert_equal users_id(:su), su[:id]
    su.site = site
    assert su.is_su?
    
    login(:incognito)
    site = sites(:ocean)
    su = site.su
    assert_kind_of User, su
    assert_equal 'Hyper', su.first_name
    assert_equal users_id(:ocean_su), su[:id]
    su.site = site
    assert su.is_su?
  end
  
  def test_public_group
    site = sites(:zena)
    grp = site.public_group
    assert_kind_of Group, grp
    assert_equal groups_id(:public), grp[:id]
    
    site = sites(:ocean)
    $_test_site = 'ocean'
    grp = site.public_group
    assert_kind_of Group, grp
    assert_equal groups_id(:public), grp[:id]
  end
  
  def test_site_group
    site = sites(:zena)
    grp = site.site_group
    assert_kind_of Group, grp
    assert_equal groups_id(:workers), grp[:id]
    $_test_site = 'ocean'
    site = sites(:ocean)
    grp = site.site_group
    assert_kind_of Group, grp
    assert_equal groups_id(:aqua), grp[:id]
  end
  
  def test_monolingual
    site = sites(:zena)
    assert !site.monolingual?, "Multi lang site"
    site.monolingual = true
    assert site.save, "Can save"
    assert site.monolingual?, "Mono lang site"
  end
  
  def test_allow_private
    site = sites(:zena)
    assert site.allow_private?, "Private nodes allowed"
    site.allow_private = false
    assert site.save, "Can save"
    assert !site.allow_private?, "Private nodes not allowed"
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
  
  def test_redit_time
    site = sites(:ocean)
    assert_equal '2 hours', site.redit_time
    site.redit_time = '0'
    assert_equal '0', site.redit_time
    assert site.save
    site = sites(:ocean)
    assert_equal '0', site.redit_time
    assert site.update_attributes(:redit_time => '5h 1d 34 seconds')
    assert_equal '1 day 5 hours 34 seconds', site.redit_time
  end
  
  def test_site_attributes
    login(:lion)
    site = sites(:zena)
    assert site.update_attributes(:d_recaptcha_pub => "something", :d_recaptcha_priv => "anything else")
    site = sites(:zena)
    assert_equal "something", site.d_recaptcha_pub
    assert_equal "something", site.dyn['recaptcha_pub']
    assert_equal "anything else", site.d_recaptcha_priv
    assert_equal "anything else", site.dyn['recaptcha_priv']
  end
  
  def test_attributes_for_form
    puts Site.attributes_for_form.inspect
  end
end
