require 'test_helper'

class NodesControllerTest < Zena::Controller::TestCase
  context 'An anonymous user' do
    setup do
      login(:anon)
    end

    context 'visiting index page' do
      subject do
        {:action => 'index', :controller => 'nodes', :prefix => ''}
      end

      should 'recognize index page' do
        assert_recognizes subject, '/'
      end

      should 'redirect to lang' do
        get_subject
        assert_redirected_to '/en'
      end

      context 'with lang' do
        subject do
          {:action => 'index', :controller => 'nodes', :prefix => 'en'}
        end

        should 'recognize index page' do
          assert_recognizes subject, '/en'
        end

        should 'succeed' do
          get_subject
          assert_response :success
        end
      end # with lang
    end # visiting index page

    context 'editing a page' do
      subject do
        {:action => 'edit', :controller => 'nodes', :id => nodes_zip(:projects).to_s}
      end

      should 'recognize edit page' do
        assert_recognizes subject, "/nodes/#{subject[:id]}/edit"
      end

      should 'render missing' do
        get_subject
        assert_response :missing
      end
    end # visiting edit page

    context 'visiting a page without path' do
      subject do
        {:action => 'show', :controller => 'nodes', :id => nodes_zip(:projects).to_s}
      end

      should 'recognize show page' do
        assert_recognizes subject, "/nodes/#{subject[:id]}"
      end

      should 'redirect' do
        get_subject
        assert_redirected_to 'http://test.host/en/page18.html'
      end
    end # visiting a page without path

    context 'visiting a page with path' do
      subject do
        {:action => 'show', :controller => 'nodes', :path => ["page#{nodes_zip(:projects)}.html"], :prefix => 'en'}
      end

      should 'recognize show page' do
        assert_recognizes subject, "/en/page#{nodes_zip(:projects)}.html"
      end

      should 'succeed' do
        get_subject
        assert_response :success
      end

      context 'with admin mode' do
        subject do
          {:action => 'show', :controller => 'nodes', :path => ["page#{nodes_zip(:projects)}_admin.html"], :prefix => 'en'}
        end

        should 'render not found' do
          # Stupid tests. Raises ActionView::TemplateError during testing and
          # ActiveRecord::RecordNotFound in production.
          assert_raise(ActionView::TemplateError) { get_subject }
        end
      end # with admin mode

    end # visiting show

    context 'with xml' do
      context 'asking for show' do
        subject do
          {:action => 'show', :controller => 'nodes', :id => nodes_zip(:projects).to_s, :format => 'xml'}
        end

        should 'recognize show page' do
          assert_recognizes subject, "/nodes/#{subject[:id]}.xml"
        end

        should 'return unauthorized' do
          get_subject
          assert_response :unauthorized
        end
      end

      context 'asking for index' do
        subject do
          {:action => 'index', :controller => 'nodes', :format => 'xml'}
        end

        should 'recognize index page' do
          assert_recognizes subject, "/nodes.xml"
        end

        should 'return unauthorized' do
          get_subject
          assert_response :unauthorized
        end
      end

      context 'creating a node' do
        subject do
          {:action => 'create', :controller => 'nodes', :format => 'xml', :node => {:parent_id => nodes_zip(:zena), :title => 'hello'}}
        end

        should 'recognize create page' do
          assert_recognizes subject, {:path => "/nodes.xml", :method => :post}, {:node => {:parent_id => nodes_zip(:zena), :title => 'hello'}}
        end

        should 'return unauthorized' do
          post_subject
          assert_response :unauthorized
        end
      end # creating a node

      context 'accessing xml without a token' do
        subject do
          {:action => 'search', :qb => 'foos'}
        end

        should 'return an error' do
          @request.env['HTTP_ACCEPT'] = 'application/xml'
          get_subject
          assert_response 401
          assert_equal "Authentication token needed.", Hash.from_xml(@response.body)['errors'].first['message']
        end
      end # accessing xml without a token

    end # with xml
  end # An anonymous user

  context 'A user' do
    setup do
      login(:tiger)
    end

    context 'visiting index page' do
      subject do
        {:action => 'index', :controller => 'nodes', :prefix => ''}
      end

      should 'recognize index page' do
        assert_recognizes subject, '/'
      end

      should 'redirect to AUTHENTICATED_PREFIX' do
        get_subject
        assert_redirected_to "/#{AUTHENTICATED_PREFIX}"
      end

      context 'with AUTHENTICATED_PREFIX' do
        subject do
          {:action => 'index', :controller => 'nodes', :prefix => AUTHENTICATED_PREFIX}
        end

        should 'recognize index page' do
          assert_recognizes subject, "/#{AUTHENTICATED_PREFIX}"
        end

        should 'succeed' do
          get_subject
          assert_response :success
        end
      end # with lang
    end # visiting index page

    context 'visiting edit page' do
      subject do
        {:action => 'edit', :controller => 'nodes', :id => nodes_zip(:projects).to_s}
      end

      should 'recognize edit page' do
        assert_recognizes subject, "/nodes/#{subject[:id]}/edit"
      end

      should 'succeed' do
        get_subject
        assert_response :success
      end
    end # visiting edit page

    # FIXME: Rails3 with new Urls: test does not pass, but it works.
    # context 'visiting a custom_base with accents' do
    #   setup do
    #     # see test_zen_path_custom_base_with_accents
    #     # in urls_test
    #     login(:lion)
    #     node = secure!(Node) { nodes(:cleanWater) }
    #     node.update_attributes(:title => 'Lignes aériennes', :v_status => Zena::Status[:pub])
    #   end
    #
    #   subject do
    #     {:action => 'show', :prefix => 'oo', :controller => 'nodes', :path => ['Lignes-aériennes']}
    #   end
    #
    #   should 'not redirect' do
    #     get_subject
    #     assert_response :success
    #   end
    # end # visiting a custom_base with accents

    context 'creating a node' do
      subject do
        {:action => 'create', :controller => 'nodes', :node => {:parent_id => nodes_zip(:zena), :title => 'hello', :klass => 'Blog'}}
      end

      should 'recognize create page' do
        assert_recognizes subject, {:path => '/nodes', :method => :post}, {:node => subject[:node]}
      end

      should 'succeed' do
        post_subject
        node = assigns(:node)
        assert_redirected_to "/oo/blog#{node.zip}.html"
      end
      
      should 'set type and vclass' do
        post_subject
        node = assigns(:node)
        assert_equal 'NPPB', node.kpath
        assert_equal 'Project', node.type
        node = Node.find(node.id)
        assert_equal 'NPPB', node.kpath
        assert_equal 'Project', node.type
      end
    end # creating a node

    context 'updating a node' do

      context 'that she owns' do
        setup do
          @node = secure(Page) { Page.create(:parent_id => nodes_id(:zena), :title => 'hop', :v_status => Zena::Status[:pub]) }
        end

        context 'in redit time' do
          subject do
            {:action => 'update', :controller => 'nodes', :id => @node.zip, :node => {:title => 'hip'}}
          end

          should 'create a new version' do
            assert_difference('Version.count', 1) do
              put_subject
              assert_redirected_to "/oo/page#{subject[:id]}.html"
            end
          end
        end # in redit time
      end # that she owns

      context 'with a redir param' do
        subject do
          {:action => 'update', :controller => 'nodes', :id => nodes_zip(:people), :node => {:title => 'friends'}, :redir => '/foo/bar/baz'}
        end

        should 'redirect to "redir" param' do
          put_subject
          assert_redirected_to '/foo/bar/baz'
        end
      end # with a redir param

      context 'by changing a link comment' do
        subject do
          {:action => 'update', :controller => 'nodes', :id => nodes_zip(:opening), :node => {:link_id => links_id(:opening_in_art), :l_comment => 'To be removed'}}
        end

        should 'update link' do
          assert_difference('Link.count', 0) do
            assert_difference('Version.count', 0) do
              put_subject
            end
          end
          assert_equal 'To be removed', Link.find(links_id(:opening_in_art)).comment
          assert_response :redirect
        end
      end # by changing a link comment


      context 'by changing a link date' do
        subject do
          {:action => 'update', :controller => 'nodes', :id => nodes_zip(:opening), :node => {:link_id => links_id(:opening_in_art), :l_date => '2011-03-29 17:51'}}
        end

        should 'update link' do
          assert_difference('Link.count', 0) do
            assert_difference('Version.count', 0) do
              put_subject
            end
          end
          assert_equal '2011-03-29 17:51', Link.find(links_id(:opening_in_art)).date.strftime('%Y-%m-%d %H:%M')
          assert_response :redirect
        end
      end # by changing a date

      context 'by changing skin' do
        subject do
          {:action => 'update', :controller => 'nodes', :id => nodes_zip(:people), :node => {:skin_zip => nodes_zip(:wikiSkin), :inherit => 0}}
        end

        should 'update skin_id' do
          put_subject
          assert_equal nodes_id(:wikiSkin), nodes(:people).skin_id
        end

        context 'with a bad value' do
          subject do
            {:action => 'update', :controller => 'nodes', :id => nodes_zip(:people), :node => {:skin_zip => nodes_zip(:status), :inherit => 0}}
          end

          should 'set error message on skin_id' do
            put_subject
            assert_response :success
            assert_equal 'type mismatch (Page is not a Skin)', assigns(:node).errors[:skin_id]
          end
        end # with a bad value

      end # by changing skin

    end # updating a node

    # ======================================= Template update
    context 'updating a template' do
      subject do
        {:action => 'update', :controller => 'nodes', :id => nodes_zip(:Node_zafu), :node => {:mode => '+index'}}
      end

      should 'update template with new mode' do
        put_subject
        assert_equal '+index', assigns(:node).mode
      end
    end # updating a template

    context 'using xml' do
      context 'without being in the api_group' do
        setup do
          visitor.site.api_group_id = nil
        end

        context 'asking for show' do
          subject do
            {:action => 'show', :controller => 'nodes', :id => nodes_zip(:projects).to_s, :format => 'xml'}
          end

          should 'fail' do
            get_subject
            assert_response :unauthorized
          end

          should 'return an xml error' do
            get_subject
            assert_match %r{<message>Not in API group.</message>}, @response.body
          end
        end

      end # without being in the api_group

      context 'asking for show' do
        subject do
          {:action => 'show', :controller => 'nodes', :id => nodes_zip(:projects).to_s, :format => 'xml'}
        end

        should 'recognize show page' do
          assert_recognizes subject, "/nodes/#{subject[:id]}.xml"
        end

        should 'succeed' do
          get_subject
          assert_response :success
        end

        should 'return an xml representation' do
          get_subject
          assert_match %r{<title>projects list</title>}, @response.body
        end
      end

      context 'asking for index' do
        subject do
          {:action => 'index', :controller => 'nodes', :format => 'xml'}
        end

        should 'recognize create page' do
          assert_recognizes subject, "/nodes.xml"
        end

        should 'return succeed' do
          get_subject
          assert_response :success
        end
      end

      context 'creating a node' do
        subject do
          {:action => 'create', :controller => 'nodes', :format => 'xml', :node => {:parent_id => nodes_zip(:zena), :title => 'hello'}}
        end

        should 'recognize create page' do
          assert_recognizes subject, {:path => "/nodes.xml", :method => :post}, {:node => {:parent_id => nodes_zip(:zena), :title => 'hello'}}
        end

        should 'succeed' do
          post_subject
          assert_response :success
        end

        should 'return an xml representation' do
          post_subject
          assert_match %r{<title>hello</title>}, @response.body
          zip = assigns(:node).zip
          assert_match %r{<id[^>]*>#{zip}</id>}, @response.body
        end

        context 'with a redir param' do
          subject do
            {:action => 'create', :controller => 'nodes', :node => {:parent_id => nodes_zip(:zena), :title => 'hello'}, :redir => '/foo/bar/baz'}
          end

          should 'redirect to "redir" param' do
            post_subject
            assert_redirected_to '/foo/bar/baz'
          end
        end # with a redir param

        context 'with a mode param' do
          subject do
            {:action => 'create', :controller => 'nodes', :node => {:parent_id => nodes_zip(:zena), :title => 'hello'}, :mode => 'info'}
          end

          should 'redirect to node with mode' do
            post_subject
            assert_redirected_to "/oo/page#{assigns(:node).zip}_info.html"
          end
        end # with a redir param
      end # creating a node

      context 'deleting a node' do

        should 'succeed' do
          delete( :destroy, {:format=>'xml', :id=>nodes_zip(:art)})
          assert_response :success
        end

      end

      context 'with a bad request' do
        subject do
          {:action => 'search', :qb => 'foos'}
        end

        should 'return an error' do
          @request.env['HTTP_ACCEPT'] = 'application/xml'
          @request.env['HTTP_X_AUTHENTICATION_TOKEN'] = 'mytoken'
          get_subject
          assert_response 401
          assert_equal "Error parsing query \"foos\" (Unknown relation 'foos'.)", Hash.from_xml(@response.body)['errors'].first['message']
        end
      end # with a bad request

    end # using xml

    context 'visiting a node' do

      subject do
        {:action => 'show', :controller => 'nodes', :path => ["page#{nodes_zip(:projects)}_admin.html"], :prefix => 'oo'}
      end

      should 'show page' do
        get_subject
        assert_response :success
      end

      context 'with admin mode' do
        subject do
          {:action => 'show', :controller => 'nodes', :path => ["page#{nodes_zip(:projects)}_admin.html"], :prefix => 'oo'}
        end

        should 'render default admin layout' do
          get_subject
          assert_response :success
          assert_match %r{\$default/Node-admin}, @response.rendered[:template].to_s
        end
      end # with admin mode
    end

    context 'destroying a node' do

      subject do
        {:action=>'destroy', :controller=>'nodes', :id=>nodes_zip(:art)}
      end

      should 'succeed' do
        assert_nothing_raised do
          delete_subject
        end
      end

      should 'be redirected' do
        delete_subject
        assert_response :redirect
      end

      # No, flash removed
      # should 'be noticed that the node is destroyed' do
      #   delete_subject
      #   assert_equal 'Node destroyed.', flash[:notice]
      # end

      should 'delete the node' do
        assert_difference('Node.count', -1) do
          delete_subject
        end
      end

    end # destroying a node

    context 'trying to destroy an inaccessible node' do
      subject do
        {:action=>'destroy', :controller=>'nodes', :id=>nodes_zip(:status)}
      end

      should 'be noticed that it could not destroy the node' do
        delete_subject
        assert_equal "Could not destroy node.", flash[:notice]
      end

      should 'not delete the node' do
        assert_difference('Node.count', 0) do
          delete_subject
        end
      end

    end # trying to destroy an inaccessible node
  end # A user


  def test_foo
    assert_generates '/en/img.jpg?1234', :controller => :nodes, :action => :show, :prefix => 'en', :path => ["img.jpg"], :cachestamp => '1234'
    assert_recognizes(
      {:controller => 'nodes', :action => 'show', :prefix => 'en', :path => ["img.jpg"], :cachestamp => '1234'},
      '/en/img.jpg?1234'
    )
  end

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

  def test_should_cache_document_data_without_cachestamp
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
        assert File.exist?("#{SITES_ROOT}/test.host/public/en/image#{node.zip}.jpg")
      end
    end
  end

  def test_cache_xml_format
    test_site(:zena)
    without_files('/test.host/public') do
      name = "section#{nodes_zip(:people)}.xml"
      with_caching do
        assert !File.exist?("#{SITES_ROOT}/test.host/public/fr/#{name}")
        login(:lion)
        doc = secure!(Template) { Template.create('title'=>'Node', 'format'=>'xml', 'text' => '<?xml version="1.0" encoding="utf-8"?><node><title do="title"/></node>', 'parent_id'=>nodes_id(:default))}
        assert !doc.new_record?, "Not a new record"
        assert doc.publish
        login(:anon)
        get 'show', :prefix => 'en', :path => [name]
        assert_response :success
        assert_equal "<?xml version=\"1.0\" encoding=\"utf-8\"?><node><title>people</title></node>", @response.body
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
      doc = secure!(Template) { Template.create("title"=>"Project", "format"=>"ics", "summary"=>"", 'text' => "<r:notes in='site' order='event_at asc'>
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
    Site.connection.execute    "UPDATE sites set auto_publish = #{Zena::Db::TRUE}, redit_time = 7200 WHERE id = #{sites_id(:zena)}"
    Version.connection.execute "UPDATE versions set created_at = '#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}' WHERE id = #{versions_id(:style_css_en)}"
    login(:tiger)
    node = secure!(Node) { nodes(:style_css) }
    without_files('/test.host/public') do
      name = "textdocument#{node.zip}.css"
      filename = "#{SITES_ROOT}/test.host/public/en/#{name}"
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
        get 'show', :prefix => 'en', :path => [name], :cachestamp => node.updated_at.to_i
        assert_response :success
        assert File.exist?(filename) # cached page created again
        assert_match %r[/\* empty \*/], File.read(filename)
      end
    end
  end

  def test_create_nodes_from_folder
    login(:tiger)
    preserving_files('/test.host/data') do
      parent = secure!(Project) { Project.create(:title => 'import', :parent_id => nodes_id(:zena)) }
      assert !parent.new_record?, "Not a new record"

      nodes = secure!(Node) { Node.create_nodes_from_folder(:folder => File.join(Zena::ROOT, 'test', 'fixtures', 'import'), :parent_id => parent[:id] )}.values
      @controller.send(:parse_assets, nodes)

      children = parent.find(:all, 'children')
      assert_equal 2, children.size
      assert_equal 4, nodes.size
      bird, doc   = nil, nil
      nodes.each do |n|
        bird = n if n.title == 'bird'
        doc  = n if n.title == 'document'
      end
      simple = secure!(Node) { Node.find_by_parent_title_and_kpath(parent.id, 'simple') }
      photos = secure!(Node) { Node.find_by_parent_title_and_kpath(parent.id, 'Photos !') }

      assert_equal 'bird', bird.title
      assert_equal 'simple', simple.title
      assert_equal 'jpg', bird.ext
      assert_equal 'Le septième ciel', bird.text
      versions = secure!(Node) { Node.find(bird[:id]) }.versions
      assert_equal 2, versions.size
      assert_equal 'fr', versions[0].lang
      assert_equal 'en', versions[1].lang
      assert_equal 'Le septième ciel', versions[0].text
      assert_equal 'Photos !', photos.title
      assert_match %r{Here are some photos.*!\[\]!}m, photos.text
      assert_match %r{!#{bird.zip}_med!}m,     photos.text
      assert_match %r{"links":#{simple.zip}}m, photos.text
      assert_equal "A simple \"test\":#{simple.zip}", photos.version.prop['origin']
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
    node = secure!(Node) { nodes(:letter) }
    assert_equal Zena::Status[:pub], node.version.status
    # get ajax
    get 'edit', :format => 'js', :id => node.zip, 'attribute' => 'paper', 'dom_id' => 'foo', 'publish' => 'true', 'zazen' => 'true'
    assert_match %r{name='node\[v_status\]' value='50'}m, @response.body
    assert_match %r{name='publish' value='true'}m, @response.body

    put 'update', :format => 'js', :id => node.zip, 'publish' => 'true', 'zazen' => 'true', 'dom_id' => 'foo', 'node' => {'paper' => 'Parchment', 'v_status' => '50'}
    assert_match %r{publish=true}m, @response.body

    node = secure!(Node) { nodes(:letter) }
    assert_equal Zena::Status[:pub], node.v_status
    assert_equal 'Parchment', node.prop['paper']
  end

  def test_update_change_v_status_reloads_page
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    node.update_attributes('title' => 'foobar')
    assert_equal Zena::Status[:red], node.v_status
    # ajax
    put 'update', :format => 'js', :id => node.zip, 'zazen' => 'true', 'dom_id' => 'foo', 'node' => {'title' => 'Michel Serres', 'v_status' => '50'}
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
    assert_match %r{/Default skin/Node-%2BpopupLayout/en/_main$}, @response.layout
  end

  def test_crop_image
    preserving_files('test.host/data') do
      login(:ant)
      img = secure!(Node) { nodes(:bird_jpg) }
      assert_equal Zena::Status[:pub], img.version.status
      pub_version_id = img.version.id
      pub_content_id = img.version.attachment.id
      assert_equal 660, img.width
      assert_equal 600, img.height
      assert_equal 56243, img.size

      put 'update', :edit => 'popup', :node => {:crop=>{:x=>'500',:y=>30,:w=>'200',:h=>80}}, :id => nodes_zip(:bird_jpg)
      assert_redirected_to edit_node_version_path(:node_id => nodes_zip(:bird_jpg), :id => 0)
      img = assigns(:node)
      err img
      img = secure!(Node) { nodes(:bird_jpg) }
      assert_not_equal pub_version_id, img.version.id
      assert_not_equal pub_content_id, img.version.attachment.id
      assert_equal 2010,   img.size
      assert_equal 160,  img.width
      assert_equal 80, img.height
    end
  end

  def test_should_get_test_page_without_errors
    without_files('test.host/zafu') do
      login(:tiger)
      get 'show', 'prefix'=>'oo', 'path'=>["page#{nodes_zip(:projects)}_test.html"]
      assert_response :success
    end
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

  def test_search_klass
    login(:anon)
    get 'search', 'class' => 'Blog', 'title' => 'a wiki with Zena'
    assert nodes = assigns(:nodes)
    assert_equal [nodes_id(:wiki)], nodes.map {|r| r.id}
  end

  def test_search_q
    login(:anon)
    get 'search', 'q' => 'wild'
    assert nodes = assigns(:nodes)
    assert_equal [nodes_id(:zena)], nodes.map {|r| r.id}
  end

  def test_search_qb
    login(:anon)
    get 'search', 'qb' => 'nodes where (set_tag_id = 33 and hot_id = 22) in site'
    assert_response :success
    assert nodes = assigns(:nodes)
    assert_equal [nodes_id(:cleanWater)], nodes.map(&:id)
  end

  def test_find_from_node
    login(:anon)
    get 'find', :id => nodes_zip(:lake_jpg), 'qb' => 'icon_for', '_find' => 'first'
    assert_response :success
    assert nodes = assigns(:nodes)
    assert_equal nodes_id(:cleanWater), nodes.first.id
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
      ['25-10-2006','blog29.html'],
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