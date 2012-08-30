require 'test_helper'
CachedPage
class CachedPage
  def randomize_visited_nodes!
    @expire_with = (200 * rand).to_i.times { ids << (500000 * rand).to_i}
  end
end
class CachedPageTest < Zena::Unit::TestCase

  def test_create
    without_files('test.host/public') do
      preserving_files('/test.host/data') do
        with_caching do
          login(:anon)
          secure!(Node) { nodes(:status) }
          secure!(Node) { nodes(:bird_jpg) }
          assert_equal [nodes_id(:status), nodes_id(:bird_jpg)], visitor.visited_node_ids
          path = "#{SITES_ROOT}#{visitor.site.public_path + "/some/place.html"}"
          assert !File.exists?(path), "No cached file yet"
          cache = secure!(CachedPage) { CachedPage.create(
            :path => (visitor.site.public_path + "/some/place.html"),
            :expire_after  => nil,
            :content_data => "this is the cached content") }
          assert File.exists?(path), "Cache file created"
          data = File.open(path) {|f| f.read }
          assert_equal "this is the cached content", data
          assert_equal [nodes_id(:status), nodes_id(:bird_jpg)], cache.node_ids
          # test expire
          login(:tiger)
          node = secure!(Node) { nodes(:status) }
          assert node.update_attributes(:title=>'hey', :v_status => Zena::Status::Pub), "Can save"
          assert !File.exists?(path), "Cache file removed"
          assert_equal [], cache.node_ids
        end
      end
    end
  end

  def test_create_symlink
    without_files('test.host/public') do
      preserving_files('/test.host/data') do
        with_caching do
          login(:anon)
          node = secure!(Node) { nodes(:bird_jpg) }
          path = "#{SITES_ROOT}#{visitor.site.public_path + "/some/place/image12.jpg"}"
          assert !File.exists?(path), "No cached file yet"
          cache = secure!(CachedPage) { CachedPage.create(
            :path => (visitor.site.public_path + "/some/place/image12.jpg"),
            :expire_after  => nil,
            :content_path  => node.filepath) }
          assert File.exists?(path), "Cache file created"
          assert File.symlink?(path), "Cache file is a symlink"
          # test expire
          login(:tiger)
          node = secure!(Node) { nodes(:bird_jpg) }
          assert node.update_attributes(:title=>'hey', :v_status => Zena::Status::Pub), "Can save"
          assert !File.exists?(path), "Cache file removed"
          login(:anon)
          node = secure!(Node) { nodes(:bird_jpg) }
          cache = secure!(CachedPage) { CachedPage.create(
            :path => (visitor.site.public_path + "/some/place/image12.jpg"),
            :expire_after  => nil,
            :content_path  => node.filepath) }
          assert File.exists?(path), "Cache file created"
          login(:tiger)
          # edit node only
          node = secure!(Node) { nodes(:bird_jpg) }
          assert node.update_attributes(:title => 'hey'), "Can save"
          assert !File.exists?(path), "Cache file removed"
        end
      end
    end
  end

  def test_expire_old
    without_files('test.host/public') do
      with_caching do
        login(:anon)
        secure!(Node) { nodes(:status) }
        secure!(Node) { nodes(:bird_jpg) }
        assert_equal [nodes_id(:status), nodes_id(:bird_jpg)], visitor.visited_node_ids
        path = "#{SITES_ROOT}#{visitor.site.public_path + "/some/place.html"}"
        assert !File.exists?(path), "No cached file yet"
        cache = secure!(CachedPage) { CachedPage.create(
          :path => (visitor.site.public_path + "/some/place.html"),
          :expire_after  => Time.now - 3600,
          :content_data => "this is the cached content") }
        assert File.exists?(path), "Cache file created"
        data = File.open(path) {|f| f.read }
        assert_equal "this is the cached content", data
        assert_equal [nodes_id(:status), nodes_id(:bird_jpg)], cache.node_ids
        # test expire
        CachedPage.expire_old
        assert !File.exists?(path), "Cache file removed"
        assert_equal [], cache.node_ids
      end
    end
  end

  def test_site_id
    without_files('test.host/public') do
      with_caching do
        login(:anon)
        secure!(Node) { nodes(:people) }
        cache = secure!(CachedPage) { CachedPage.create(
          :path => (visitor.site.public_path + "/some/place.html"),
          :expire_after  => nil,
          :content_data => "this is the cached content") }
        assert !cache.new_record?, "Not a new record"
        assert_equal sites_id(:zena), cache[:site_id]
      end
    end
  end

  def test_cannot_set_site_id
    without_files('test.host/public') do
      with_caching do
        login(:anon)
        secure!(Node) { nodes(:people) }
        cache = secure!(CachedPage) { CachedPage.new(
          :path         => (visitor.site.public_path + "/some/place.html"),
          :expire_after => nil,
          :content_data => "this is the cached content",
          :site_id      => sites_id(:ocean))}

        assert_nil cache.site_id

        cache = secure!(CachedPage) { CachedPage.create(
          :path         => (visitor.site.public_path + "/some/place.html"),
          :expire_after => nil,
          :content_data => "this is the cached content") }

        assert !cache.new_record?, "Not a new record"
        cache.update_attributes(:site_id => 1234 )
        assert_equal sites_id(:zena), cache[:site_id]
      end
    end
  end

  def test_create_for_zafu_template
    without_files('test.host/zafu') do
      preserving_files('/test.host/data') do
        login(:anon)
        template_ids = [nodes_id(:Node_index_zafu), nodes_id(:Project_zafu), nodes_id(:Node_zafu), nodes_id(:notes_zafu)]
        path = SITES_ROOT + visitor.site.zafu_path + "/default/Node-foobar/en/main.erb"
        assert !File.exists?(path), "No cached file yet"
        cache = secure!(CachedPage) { CachedPage.create(
          :path            => (visitor.site.zafu_path + "/default/Node-foobar/en/main.erb"),
          :expire_after    => nil,
          :expire_with_ids => template_ids,
          :content_data    => "this is the cached content") }
        assert File.exists?(path), "Cache file created"
        data = File.open(path) {|f| f.read }
        assert_equal "this is the cached content", data
        assert_equal template_ids.sort, cache.node_ids.map{|i| i.to_i}.sort
        # test expire
        login(:tiger)
        node = secure!(Node) { nodes(:Node_zafu) }
        assert node.update_attributes(:title=>'hey', :v_status => Zena::Status::Pub), "Can save"
        assert !File.exists?(path), "Cache file removed"
        assert_equal [], cache.node_ids
      end
    end
  end

  def test_no_expire_in_dev
    without_files('test.host/zafu') do
      preserving_files('/test.host/data') do
        login(:lion)
        visitor.dev_skin_id = nodes_id(:default)
        assert visitor.dev_mode?
        template_ids = [nodes_id(:Node_index_zafu), nodes_id(:Project_zafu), nodes_id(:Node_zafu), nodes_id(:notes_zafu)]
        path = SITES_ROOT + visitor.site.zafu_path + "/default/Node-foobar/en/_main.erb"
        dev_path = SITES_ROOT + visitor.site.zafu_path + "/default/Node-foobar/dev_en/_main.erb"

        assert !File.exists?(path), "No cached file yet"
        cache = secure!(CachedPage) { CachedPage.create(
          :path            => (visitor.site.zafu_path + "/default/Node-foobar/en/_main.erb"),
          :expire_after    => nil,
          :expire_with_ids => template_ids,
          :content_data    => "public cache") }

        cache = secure!(CachedPage) { CachedPage.create(
          :path            => (visitor.site.zafu_path + "/default/Node-foobar/dev_en/_main.erb"),
          :expire_after    => nil,
          :expire_with_ids => template_ids,
          :content_data    => "dev cache") }
        assert File.exists?(path), "Cache file created"  
        assert File.exists?(dev_path), "Cache file created"
        
        # test expire
        node = secure!(Node) { nodes(:Node_zafu) }
        assert node.update_attributes(:title => 'hey', :v_status => Zena::Status::Pub), "Can save"
        assert File.exists?(path), "Public cache not removed (#{path})"
        assert !File.exists?(dev_path), "Dev cache removed (#{dev_path})"
        
        # expire all
        assert current_site.update_attributes(:expire_in_dev => true)
        node = secure!(Node) { nodes(:Node_zafu) }
        assert node.update_attributes(:title=>'hey boy', :v_status => Zena::Status::Pub), "Can save"
        assert !File.exists?(path), "Public cache removed"
      end
    end
  end
end