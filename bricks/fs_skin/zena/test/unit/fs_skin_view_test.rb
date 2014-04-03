require File.dirname(__FILE__) + '/../../../../../test/test_helper'

class FsSkinViewTest < Zena::View::TestCase

  context 'A page using a fs_skin Skin' do
    setup do
      login(:lion)
      skin = secure(Skin) { Skin.create(:title => 'foo', :z_fs_skin => 'fs_skin-blog', :parent_id => nodes_id(:skins), :v_status => Zena::Status::Pub)}
      assert skin.errors.empty?
    end
    
    context 'with a normal user' do
      setup do
        login(:anon)
        visiting(:status)
      end
      
      should 'build template partial on template_path_from_template_url and ignore skin' do
        puts "\n\n\n\n ********************************************************"
        puts " ********************************************************"
        puts " ******************** RUNNING FS_SKIN TESTS **************"
        puts " ********************************************************"
        puts " ********************************************************\n\n\n"
        fullpath  = fullpath_from_template_url('$fs_skin-blog/Node/pages', false)
        main_path = fullpath_from_template_url('$fs_skin-blog/Node/_main', false)
        FileUtils.rm(fullpath)  if File.exist?(fullpath)
        FileUtils.rm(main_path) if File.exist?(main_path)
        assert_equal '/test.host/zafu/$fs_skin-blog/Node/en/pages.erb', template_path_from_template_url('', '$fs_skin-blog/Node/pages', true)
        assert File.exist?(main_path)
        assert File.exist?(fullpath)
        FileUtils.rm(fullpath)
      end
    end
  end # A page using a fs_skin Skin
end