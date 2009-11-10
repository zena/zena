require 'test_helper'

class SiteTest < Zena::Unit::TestCase

  context 'on site creation' do
    setup do
      @site = Site.create_for_host('super.host', 'secret')
    end

    should 'populate super user' do
      assert_equal "Super User", @site.su.fullname
      assert_not_equal users(:su), @site.su[:id]
    end

    should 'populate anonymous user' do
      assert_equal "Anonymous User", @site.anon.fullname
      assert_not_equal users(:anon), @site.anon[:id]
    end

    should 'populate 2 admin users' do
      assert_equal 2, @site.admin_user_ids.size
    end

    should 'return a new project as root node' do
      assert_kind_of Project, @site.root_node
    end
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
      assert_equal 7200, site[:redit_time] # default 2h
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
    assert_equal 'is invalid', site.errors[:languages]
    site = sites(:zena)
    assert ! site.update_attributes(:languages => "fr,en", :default_lang=>'')
    assert_equal 'is invalid', site.errors[:default_lang]
    site = sites(:zena)
    assert ! site.update_attributes(:languages => "fr,en", :default_lang=>'french')
    assert_equal 'is invalid', site.errors[:default_lang]
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
    assert_equal "something", site.dyn['recaptcha_pub']
    assert_equal "something", site.dyn['recaptcha_pub']
    assert_equal "anything else", site.dyn['recaptcha_priv']
    assert_equal "anything else", site.dyn['recaptcha_priv']
  end

  def test_attributes_for_form
    assert Site.attributes_for_form[:bool].include?(:authentication)
    assert Site.attributes_for_form[:text].include?(:default_lang)
  end

  def test_find_by_host
    site1 = Site.find_by_host('test.host')
    site2 = Site.find_by_host('test.host.')
    assert_equal site1, site2
    assert_equal "/test.host/public", site2.public_path
    assert_equal "/test.host/public", site1.public_path
  end

  def test_rebuild_vhash
    login(:tiger)
    Node.connection.execute "UPDATE nodes SET vhash = NULL WHERE id IN (#{nodes_id(:status)}, #{nodes_id(:opening)})"
    visitor.site.rebuild_vhash
    status  = secure(Node) { nodes(:status)  }
    opening = secure(Node) { nodes(:opening) }
    assert_equal Hash['w'=>{'fr' => versions_id(:status_fr),      'en' => versions_id(:status_en)},
                      'r'=>{'fr' => versions_id(:status_fr),      'en' => versions_id(:status_en)}], status.vhash

    assert_equal Hash['w'=>{'fr' => versions_id(:opening_red_fr), 'en' => versions_id(:opening_en)},
                      'r'=>{'fr' => versions_id(:opening_fr),     'en' => versions_id(:opening_en)}], opening.vhash
  end
  
  def test_rebuild_fullpath
    login(:tiger)
    Node.connection.execute "UPDATE nodes SET fullpath = NULL"
    visitor.site.rebuild_fullpath
    status  = secure(Node) { nodes(:status)  }
    opening = secure(Node) { nodes(:opening) }
    cleanWater = secure(Node) { nodes(:cleanWater) }
    art = secure(Node) { nodes(:art) }
    assert_equal 'projects/cleanWater/status', status.fullpath
    assert_equal 'projects/cleanWater', status.basepath
    assert_equal false, status.custom_base
    
    assert_equal 'projects/cleanWater/opening', opening.fullpath
    assert_equal 'projects/cleanWater', opening.basepath
    assert_equal false, opening.custom_base
    
    assert_equal 'projects/cleanWater', cleanWater.fullpath
    assert_equal 'projects/cleanWater', cleanWater.basepath
    assert_equal true, cleanWater.custom_base
    
    assert_equal 'collections/art', art.fullpath
    assert_equal '', art.basepath
    assert_equal false, art.custom_base
  end
end
