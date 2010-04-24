require 'test_helper'

class NodesControllerTest < Zena::Controller::TestCase

  def test_foo
    assert_generates '/en/img.jpg?1234', :controller => :nodes, :action => :show, :prefix => 'en', :path => ["img.jpg"], :cachestamp => '1234'
    assert_recognizes(
      {:controller => 'nodes', :action => 'show', :prefix => 'en', :path => ["img.jpg"], :cachestamp => '1234'},
      '/en/img.jpg?1234'
    )
  end
  
  context 'With a logged in visitor' do
    setup do
      login(:tiger)
    end

    context 'a version' do
      subject do
        versions(:status_en)
      end

      context 'receiving author' do
        should 'return a Contact' do
          assert_kind_of Contact, subject.author
        end

        should 'return the contact node of the author' do
          assert_equal nodes_id(:ant), subject.author[:id]
        end
      end # receiving author

      # Workflow testing....
      should 'ignore workflow attributes on edited' do
        subject.attributes = {'title' => 'status title', 'publish_from' => Time.now}
        assert subject.changed?
        assert !subject.edited?
      end

      should 'use properties on edited' do
        subject.attributes = {'title' => 'Foo title'}
        assert subject.changed?
        assert subject.edited?
      end


      def test_edited
        v = versions(:zena_en)
        assert !v.edited?
        v.status = 999
        assert !v.edited?
        v.title = 'new title'
        assert v.edited?
      end

    end # a version


    context 'a redaction' do
      subject do
        versions(:opening_red_fr)
      end
    end # a redaction

    context 'on node creation' do
      context 'setting an invalid v_lang' do
        setup do
          @node = secure!(Page) { Page.create(:v_lang => 'io', :parent_id => nodes_id(:status), :node_name => 'hello')}
        end

        should 'not create record if lang is not allowed' do
          assert @node.new_record?
        end

        should 'return an error on v_lang' do
          assert @node.errors[:v_lang].any?
        end
      end

      context 'setting a valid v_lang' do
        subject do
          @node = secure!(Page) { Page.create(:v_lang => 'de', :parent_id => nodes_id(:status), :node_name => 'hello')}
        end
  
        should 'change visitor lang' do
          assert_equal 'en', visitor.lang
          subject
          assert_equal 'de', visitor.lang
        end
      end # setting a valid v_lang
    end # on node creation
  end # With a logged in visitor

  def test_should_get_document_data
    login(:tiger)
    node = secure!(Node) { nodes(:bird_jpg) }
    get 'show', :prefix => 'oo', :path => ["image#{node.zip}.jpg"]
    # missing cache info
    assert_redirected_to "/en/image#{node.zip}.jpg?#{node.updated_at.to_i}"
    # bad cache info
    get 'show', :prefix => 'en', :path => ["image#{node.zip}.jpg"], :cachestamp => '1234'
    assert_redirected_to "/en/image#{node.zip}.jpg?#{node.updated_at.to_i}"
    # cache info ok
    get 'show', :prefix => 'en', :path => ["image#{node.zip}.jpg"], :cachestamp => node.updated_at.to_i
    assert_response :success
  end

  def test_should_get_document_data_with_mode
    login(:tiger)
    node = secure!(Node) { nodes(:bird_jpg) }
    get 'show', :prefix => 'oo', :path => ["image#{node.zip}_pv.jpg"]
    # missing cache info, can use public image
    assert_redirected_to "/en/image#{node.zip}_pv.jpg?#{node.updated_at.to_i + Iformat['pv'][:hash_id]}"
    # bad cache info
    get 'show', :prefix => 'en', :path => ["image#{node.zip}.jpg"], :cachestamp => '1234'
    assert_redirected_to "/en/image#{node.zip}.jpg?#{node.updated_at.to_i}"
    # cache info ok
    get 'show', :prefix => 'en', :path => ["image#{node.zip}.jpg"], :cachestamp => node.updated_at.to_i
    assert_response :success
  end

  def test_should_get_document_css
    login(:tiger)
    node = secure!(Node) { nodes(:style_css) }
    get 'show', :prefix => 'oo', :path => ["textdocument#{node.zip}.css"]
    # missing cache info, should use public lang
    assert_redirected_to "/en/textdocument#{node.zip}.css?#{node.updated_at.to_i}"
    # bad cache info
    get 'show', :prefix => 'en', :path => ["textdocument#{node.zip}.css"], :cachestamp => '1234'
    assert_redirected_to "/en/textdocument#{node.zip}.css?#{node.updated_at.to_i}"
    # cache info ok
    get 'show', :prefix => 'en', :path => ["textdocument#{node.zip}.css"], :cachestamp => node.updated_at.to_i
    assert_response :success
  end

  def test_should_cache_document_data_with_cachestamp
    with_caching do
     without_files('/test.host/public') do
        login(:anon)
        node = secure!(Node) { nodes(:bird_jpg) }
        get 'show', :prefix => 'en', :path => ["image#{node.zip}.jpg"]
        # missing cache info
        assert_redirected_to "/en/image#{node.zip}.jpg?#{node.updated_at.to_i}"
        assert !File.exist?("#{SITES_ROOT}/test.host/public/en/image#{node.zip}.jpg")
        # bad cache info
        get 'show', :prefix => 'en', :path => ["image#{node.zip}.jpg"], :cachestamp => '1234'
        assert_redirected_to "/en/image#{node.zip}.jpg?#{node.updated_at.to_i}"
        assert !File.exist?("#{SITES_ROOT}/test.host/public/en/image#{node.zip}.jpg")
        # cache info ok
        get 'show', :prefix => 'en', :path => ["image#{node.zip}.jpg"], :cachestamp => node.updated_at.to_i
        assert_response :success
        assert File.exist?("#{SITES_ROOT}/test.host/public/en/image#{node.zip}.jpg?#{node.updated_at.to_i}")
      end
    end
  end

  def test_cache_xml_format
   without_files('/test.host/public') do
      name = "section#{nodes_zip(:people)}.xml"
      with_caching do
        assert !File.exist?("#{SITES_ROOT}/test.host/public/fr/#{name}")
        login(:lion)
        doc = secure!(Template) { Template.create("node_name"=>"Node", "c_format"=>"xml", "summary"=>"", 'text' => '<?xml version="1.0" encoding="utf-8"?><node><name do="[name]"/></node>', "parent_id"=>nodes_id(:default))}
        assert !doc.new_record?, "Not a new record"
        assert doc.publish
        login(:anon)
        get 'show', :prefix => 'en', :path => [name]
        assert_response :success
        assert_equal "<?xml version=\"1.0\" encoding=\"utf-8\"?><node><name>people</name></node>", @response.body
        assert File.exist?("#{SITES_ROOT}/test.host/public/en/#{name}")
      end
    end
  end

  def test_update_l_status
    login(:lion)
    opening = secure!(Node) { nodes(:opening) }
    art = opening.find(:first, 'set_tag')
    assert_equal 5, art.l_status
    put 'update', :id => art[:zip], :node => {:l_status => 54321}, :link_id => links_id(:opening_in_art)
    art = assigns(:node)
    assert_equal 54321, art.l_status
    # reload
    opening = secure!(Node) { nodes(:opening) }
    art = opening.find(:first, 'set_tag')
    assert_equal 54321, art.l_status
  end

  def test_ics_format_not_anon
    preserving_files('test.host/zafu') do
      login(:lion)
      doc = secure!(Template) { Template.create("node_name"=>"Project", "c_format"=>"ics", "summary"=>"", 'text' => "<r:notes in='site' order='event_at asc'>
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//hacksw/handcal//NONSGML v1.0//EN
<r:each>BEGIN:VEVENT
DTSTART:<r:show date='log_at' format='%Y%m%dT%H%M%S'/>
DTEND:<r:show date='event_at' format='%Y%m%dT%H%M%S'/>
SUMMARY:<r:show attr='title'/>
URL;VALUE=URI:<r:show attr='url'/>
END:VEVENT</r:each>
END:VCALENDAR
</r:notes>", "parent_id"=>nodes_id(:default))}
      assert !doc.new_record?, "Not a new record"
      assert doc.publish
      get 'show', :prefix => 'oo', :path => ["project#{nodes_zip(:zena)}.ics"]
      assert_response :success
      assert_match %r{parc opening.*zena enhancements}m, @response.body
    end
  end

  def test_cache_css_auto_publish
    test_site('zena')
    Site.connection.execute    "UPDATE sites set auto_publish = 1, redit_time = 7200 WHERE id = #{sites_id(:zena)}"
    Version.connection.execute "UPDATE versions set created_at = '#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}' WHERE id = #{versions_id(:style_css_en)}"
    login(:tiger)
    node = secure!(Node) { nodes(:style_css) }
    without_files('/test.host/public') do
      name = "textdocument#{node.zip}.css"
      base_filename = "#{SITES_ROOT}/test.host/public/en/#{name}"
      filename = "#{base_filename}?#{node.updated_at.to_i}"
      with_caching do
        assert !File.exist?(filename)
        get 'show', :prefix => 'en', :path => [name], :cachestamp => node.updated_at.to_i
        assert_response :success
        assert File.exist?(filename) # cached page created
        assert_match %r[body \{ background: #eee; color:#444;], File.read(filename)
        put 'save_text', :id => nodes_zip(:style_css), :node => {'text' => '/* empty */'}
        node = assigns['node']
        assert node.errors.empty?
        assert_equal Zena::Status[:pub], node.version.status
        assert_equal versions_id(:style_css_en), node.version.id # auto publish
        assert !File.exist?(filename) # old cached page removed
        filename = "#{base_filename}?#{node.updated_at.to_i}"
        assert !File.exist?(filename) # not yet created
        get 'show', :prefix => 'en', :path => [name], :cachestamp => node.updated_at.to_i
        assert_response :success
        assert File.exist?(filename) # cached page created again
        assert_match %r[/\* empty \*/], File.read(filename)
      end
    end
  end

  def test_import_xhtml
    login(:tiger)
    preserving_files('/test.host/data') do
      post 'import', :id => nodes_zip(:skins), :node => {:klass => 'Skin', :v_status => Zena::Status[:pub]}, :attachment => uploaded_archive('jet_30.zip')
      node_list = assigns(:nodes)
      nodes = {}
      node_list.each do |n|
        nodes[n.name] = n
      end
      assert skin = nodes['jet30']
      assert_kind_of Skin, skin

      assert zafu = nodes['Node']
      assert_kind_of Template, zafu
      assert_equal 'html', zafu.format
      assert_equal 'Node', zafu.klass
      assert_equal 'N', zafu.tkpath
      assert style = nodes['style']
      assert_kind_of TextDocument, style
      assert navBar = nodes['navBar']
      assert_kind_of Image, navBar
      assert xhtmlBgHover = nodes['xhtmlBgHover']
      assert_kind_of Image, xhtmlBgHover
      assert topIcon = nodes['topIcon']
      assert_kind_of Image, topIcon
      ['lftPic1', 'lftPic2', 'lftPic3'].each do |p|
        assert nodes[p]
        assert_kind_of Image, nodes[p]
      end
      assert_match %r{#header ul\{\s*background:url\('/en/image#{navBar.zip}.gif\?#{navBar.updated_at.to_i}'\)}m, style.text
      assert_match %r{a\.xht:hover\{\s*background:url\('/en/image#{xhtmlBgHover.zip}.gif\?#{xhtmlBgHover.updated_at.to_i}'\)}, style.text

      # use this template
      status = secure(Node) { nodes(:status) }
      assert status.update_attributes(:skin => 'jet30', :inherit => 0)
      get 'show', 'prefix'=>'oo', 'path'=>['projects', 'cleanWater', "page#{nodes_zip(:status)}.html"]
      assert_response :success

      assert_match %r{posuere eleifend arcu</p>\s*<img [^>]*src\s*=\s*./en/image#{topIcon.zip}.gif}, @response.body
    end
  end

  def test_create_nodes_from_folder
    login(:tiger)
    preserving_files('/test.host/data') do
      parent = secure!(Project) { Project.create(:node_name => 'import', :parent_id => nodes_id(:zena)) }
      assert !parent.new_record?, "Not a new record"

      nodes = secure!(Node) { Node.create_nodes_from_folder(:folder => File.join(Zena::ROOT, 'test', 'fixtures', 'import'), :parent_id => parent[:id] )}.values
      @controller.send(:parse_assets, nodes)

      children = parent.find(:all, 'children')
      assert_equal 2, children.size
      assert_equal 4, nodes.size
      bird, doc   = nil, nil
      nodes.each do |n|
        bird = n if n[:node_name] == 'bird'
        doc  = n if n[:node_name] == 'document'
      end
      simple = secure!(Node) { Node.find_by_node_node_name_and_parent_id('simple', parent[:id]) }
      photos = secure!(Node) { Node.find_by_node_node_name_and_parent_id('photos', parent[:id]) }

      assert_equal 'bird', bird[:node_name]
      assert_equal 'simple', simple[:node_name]
      assert_equal 'The sky is blue', simple.title
      assert_equal 'jpg', bird.ext
      assert_equal 'Le septième ciel', bird.title
      versions = secure!(Node) { Node.find(bird[:id]) }.versions
      assert_equal 2, versions.size
      assert_equal 'fr', versions[0].lang
      assert_equal 'en', versions[1].lang
      assert_equal 'Le septième ciel', versions[0].title
      assert_equal 'Photos !', photos.title
      assert_match %r{Here are some photos.*!\[\]!}m, photos.text
      assert_match %r{!#{bird.zip}_med!}m,     photos.text
      assert_match %r{"links":#{simple.zip}}m, photos.text
      assert_equal "A simple \"test\":#{simple.zip}", photos.version.prop['foo']
      in_photos = photos.find(:all, 'children')
      assert_equal 2, in_photos.size

      assert_equal bird[:id], in_photos[0][:id]
      assert_equal doc[:id], in_photos[1][:id]
      doc = secure!(Node) { Node.find(doc.id) }
      doc_versions = doc.versions.sort { |a,b| a[:lang] <=> b[:lang]}
      assert_equal 2, doc_versions.size
      assert_match %r{two}, doc_versions[0].text
      assert_match %r{deux}, doc_versions[1].text
    end
  end

  def test_edit_attribute_publish
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    assert_equal Zena::Status[:pub], node.version.status
    # get ajax
    get 'edit', :format => 'js', :id => node.zip, 'attribute' => 'd_philosopher', 'dom_id' => 'foo', 'publish' => 'true', 'zazen' => 'true'
    assert_match %r{name='node\[v_status\]' value='50'}m, @response.body
    assert_match %r{name='publish' value='true'}m, @response.body

    put 'update', :format => 'js', :id => node.zip, 'publish' => 'true', 'zazen' => 'true', 'dom_id' => 'foo', 'node' => {'d_philosopher' => 'Michel Serres', 'v_status' => '50'}
    assert_match %r{publish=true}m, @response.body

    node = secure!(Node) { nodes(:status) }
    assert_equal Zena::Status[:pub], node.v_status
    assert_equal 'Michel Serres', node.d_philosopher
  end

  def test_update_change_v_status_reloads_page
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    node.update_attributes('title' => 'foobar')
    assert_equal Zena::Status[:red], node.v_status
    # ajax
    put 'update', :format => 'js', :id => node.zip, 'zazen' => 'true', 'dom_id' => 'foo', 'node' => {'d_philosopher' => 'Michel Serres', 'v_status' => '50'}
    node = secure!(Node) { nodes(:status) }
    assert_equal Zena::Status[:pub], node.v_status
    assert_match %r{window.location.href = window.location.href}m, @response.body
  end

  def test_drive_popup
    test_site('zena')
    get 'edit', :id => nodes_zip(:zena)
    assert_response :missing
    login(:lion)
    get 'edit', :id => nodes_zip(:zena)
    assert_response :success
    assert_template 'nodes/edit'
    assert_match %r{/default/Node-\+popupLayout/en/_main$}, @response.layout
  end

  def test_crop_image
    preserving_files('test.host/data') do
      login(:ant)
      img = secure!(Node) { nodes(:bird_jpg) }
      assert_equal Zena::Status[:pub], img.version.status
      pub_version_id = img.version.id
      pub_content_id = img.id
      assert_equal 660, img.width
      assert_equal 600, img.height
      assert_equal 56243, img.size

      put 'update', :edit => 'popup', :node => {:c_crop=>{:x=>'500',:y=>30,:w=>'200',:h=>80}}, :id => nodes_zip(:bird_jpg)
      assert_redirected_to edit_node_version_path(:node_id => nodes_zip(:bird_jpg), :id => 0)
      img = assigns(:node)
      err img
      img = secure!(Node) { nodes(:bird_jpg) }
      assert_not_equal pub_version_id, img.version.id
      assert_not_equal pub_content_id, img.id
      assert_equal 2010,   img.size
      assert_equal 160,  img.width
      assert_equal 80, img.height
    end
  end

  def test_should_get_test_page_without_errors
    login(:tiger)
    get 'show', 'prefix'=>'oo', 'path'=>["page#{nodes_zip(:projects)}_test.html"]
    assert_response :success
  end

  def test_create_from_url
    login(:tiger)
    if Zena::Use::Upload.has_network?
      preserving_files('test.host/data') do
        assert_difference('Node.count', 1) do
          post 'create', 'attachment_url' => 'http://zenadmin.org/fr/blog/image5.jpg', 'node' => {'parent_id' => nodes_zip(:zena)}
        end
        document = assigns(:node)
        assert_equal 73633, document.size
        assert_equal 298, document.width
        assert_equal 243, document.height
      end
    end
  end

  def test_search
    login(:anon)
    get 'search', 'q' => 'bird'
    assert nodes = assigns(:nodes)
    assert_equal [nodes_id(:bird_jpg)], nodes.map {|r| r.id}
  end
end

=begin

  def test_import_archive
    preserving_files('test.host/data') do
      login(:tiger)
      post 'import', :archive => uploaded_archive('import.tgz'), :id => nodes_zip(:status)
      assert_response :success
      assert_template 'import'
    end
  end

  def test_form_tabs
    @controller = TestNodeController.new
    init_controller
    page = @controller.send(:secure, Node) { Node.find(nodes_id(:status))    }
    @controller.instance_variable_set(:@node, page)
    assert_equal [["drive", "drive"], ["links", "links"], ["help", "help"]], @controller.send(:form_tabs)
  end

  def test_popup_page_not_found
    get 'drive', :id=>99
    assert_redirected_to :controller => 'node', :action=>'not_found'
    get 'not_found'
    assert_template 'node/not_found'
  end


  def test_add_link
    login(:tiger)
    node = secure!(Node) { nodes(:proposition) } # Post virtual class
    assert_nil node.find(:all,'blogs')
    assert_kind_of Relation, node.relation_proxy('blog')
    post 'link', 'role'=>'blog', 'id'=>nodes_zip(:proposition), 'controller'=>'nodes', 'other_id'=>nodes_zip(:cleanWater)
    assert_response :success
    node = secure!(Node) { nodes(:proposition) } # reload
    assert blogs = node.find(:all,'blogs')
    assert_equal 1, blogs.size
    assert_equal nodes_id(:cleanWater), blogs[0][:id]
  end

  def test_tags_update_string
    login(:lion)
    post 'update', :id => nodes_zip(:art), :node => {'tagged_ids' => "#{nodes_zip(:status)}, #{nodes_zip(:people)}"}

    node = secure!(Node) { nodes(:art) }
    assert_equal 2, node.tagged.size
    stat = secure!(Node) { nodes(:status) }
    peop = secure!(Node) { nodes(:people) }
    assert_equal node[:id], stat.tags[0][:id]
    assert_equal node[:id], peop.tags[0][:id]
  end

  def test_tags_update_array
    login(:lion)
    post 'update', :id => nodes_zip(:art), :node => {:tagged_ids => [nodes_zip(:lion).to_i, nodes_zip(:cleanWater).to_s]}

    node = secure!(Node) { nodes(:art) }
    assert_equal 2, node.tagged.size
    lion = secure!(Node) { nodes(:lion) }
    clea = secure!(Node) { nodes(:cleanWater) }
    assert_equal node[:id], lion.tags[0][:id]
    assert_equal node[:id], clea.tags[0][:id]
  end

  def test_create_ok
    login(:tiger)
    post 'create', :node=>{:klass=>'Tracker', :parent_id=>nodes_zip(:zena), :name=>'test'}
    assert_response :success
    assert_kind_of Page, assigns['page']
    assert assigns['page'].vkind_of?('Tracker')
    assert !assigns['page'].new_record?, "Not a new record"
  end

  def test_bad_skin_name
    login(:anon)
    without_files('zafu') do
      Node.connection.execute "UPDATE nodes SET skin = 'bad' WHERE id = #{nodes_id(:status)}"
      assert_nothing_raised do
        get 'show', "prefix"=>"en",
         "path"=>["projects", "cleanWater", "page22.html"]
      end
    end
    assert_response :success
  end

  def test_find_node
    Node.connection.execute "UPDATE nodes SET name = '2006' where id = #{nodes_id(:projects)}"
    Node.connection.execute "UPDATE nodes SET name = '25-10-2006' where id = #{nodes_id(:wiki)}"
    Node.connection.execute "UPDATE nodes SET name = 'archive-1' where id = #{nodes_id(:bird_jpg)}"
    [ ['section12.html',:success],
      ['section12_tree.xml',:success],
      ['2006','page18.html'],
      ['2006.xml','page18.xml'],
      ['p12','page12.html'],
      ['25-10-2006','project29.html'],
      ['archive-1','image30.html'],
      ['archive', 404],
    ].each do |name, result|
      puts name
      get 'show', 'prefix' => 'en', 'path' => [name]
      if result.kind_of?(String)
        assert_redirected_to 'path' => [result]
      else
        assert_response result
      end
    end
  end

  def test_cached_file
    without_files('test.host/public') do
      with_caching do
        login(:anon)
        page_path = visitor.site.public_path + '/en/section12.html'
        file_path = "#{SITES_ROOT}#{page_path}"

        assert !File.exists?(file_path), "No cached file yet"
        assert !CachedPage.find_by_path_and_site_id(page_path, sites_id(:zena)), "No cache info yet"

        get 'show', 'prefix' => 'en', 'path' => ['section12.html']
        assert_response :success

        assert File.exists?(file_path), "Cache file created"
        assert CachedPage.find_by_path_and_site_id(page_path, sites_id(:zena))
      end
    end
  end

  # test edit_... mode only if can_write?

end
=end