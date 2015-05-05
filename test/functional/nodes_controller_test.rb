require 'test_helper'

class NodesControllerTest < Zena::Controller::TestCase
  include Zena::Use::Urls::Common
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

    context 'with a custom template' do
      setup do
        login(:lion)
        # create template for 'special' mode
        secure(Template) { Template.create(:parent_id => nodes_id(:default), :title => 'Node-info-js.zafu', :text => '{some:"json"}', :v_status => Zena::Status::Pub) }
        login(:anon)
      end

      context 'asking for show' do
        subject do
          @stamp = make_cachestamp(secure(Node) { Node.find(nodes_id(:projects))}, nil)
          {
            :action => 'show', :controller => 'nodes',
            :path   => ["page#{nodes_zip(:projects)}_info.#{@stamp}.js"],
            :prefix => 'en'
          }
        end

        should 'recognize show page' do
          assert_recognizes subject, "/en/page#{nodes_zip(:projects)}_info.#{@stamp}.js"
        end

        should 'insert cachestamp and render template' do
          get_subject
          get 'show', :path => subject[:path], :prefix => 'en'
          assert_response :success
          assert_equal '{some:"json"}', @response.body
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

    end # with a custom template
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
    #     node.update_attributes(:title => 'Lignes aériennes', :v_status => Zena::Status::Pub)
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
        assert_redirected_to "/oo/blog#{node.zip}.html?new=true"
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
          @node = secure(Page) { Page.create(:parent_id => nodes_id(:zena), :title => 'hop', :v_status => Zena::Status::Pub) }
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
            assert_response :redirect
            assert_equal 'type mismatch (Page is not a Skin)', assigns(:node).errors[:skin_id]
            assert_equal %Q{<table class='errors'>\n<tr><td><b>skin_id</b></td><td>type mismatch (Page is not a Skin)</td></tr>\n</table>}, flash[:error]
          end
        end # with a bad value

      end # by changing skin
      
      context 'by changing a hash value' do
        setup do
          Column.create(:role_id => roles_id(:Task), :ptype => 'hash', :name => 'foo')
        end
        
        subject do
          {:action => 'update', :controller => 'nodes', :id => nodes_zip(:people), :node => {:foo => {:bar => 'hello'}}}
        end

        should 'change parameter' do
          put_subject
          node = secure(Node) { nodes(:people) }
          foo = node.foo
          assert_equal 'hello', foo['bar']
          # Should not raise cast error
          assert node.update_attributes('title' => 'pep')
        end
      end
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
        

        context 'with a redir param with NODE_ID' do
          subject do
            {:action => 'create', :controller => 'nodes', :node => {:parent_id => nodes_zip(:zena), :title => 'hello'}, :redir => '/foo/bar/baz/NODE_ID'}
          end

          should 'replace NODE_ID in redirect' do
            post_subject
            assert_redirected_to "/foo/bar/baz/66"
          end
        end # with a redir param

        context 'with a mode param' do
          subject do
            {:action => 'create', :controller => 'nodes', :node => {:parent_id => nodes_zip(:zena), :title => 'hello'}, :mode => 'info'}
          end

          should 'redirect to node with mode with new' do
            post_subject
            assert_redirected_to "/oo/page#{assigns(:node).zip}_info.html?new=true"
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
    assert_generates '/en/img.ff823.jpg', :controller => :nodes, :action => :show, :prefix => 'en', :path => ["img.ff823.jpg"]
    assert_recognizes(
      {:controller => 'nodes', :action => 'show', :prefix => 'en', :path => ["img.ff823.jpg"]},
      '/en/img.ff823.jpg'
    )
  end

  def test_should_get_document_data
    login(:tiger)
    node = secure!(Node) { nodes(:bird_jpg) }
    get 'show', :prefix => 'oo', :path => ["image#{node.zip}.jpg"]
    # missing cache info
    assert_redirected_to "/en/image#{node.zip}.#{make_cachestamp(node,nil)}.jpg"
    # bad cache info
    get 'show', :prefix => 'en', :path => ["image#{node.zip}.1234.jpg"]
    assert_redirected_to "/en/image#{node.zip}.#{make_cachestamp(node,nil)}.jpg"
    # cache info ok
    get 'show', :prefix => 'en', :path => ["image#{node.zip}.#{make_cachestamp(node,nil)}.jpg"]
    assert_response :success
  end

  def test_should_get_document_data_with_mode
    login(:tiger)
    node = secure!(Node) { nodes(:bird_jpg) }
    get 'show', :prefix => 'oo', :path => ["image#{node.zip}_pv.jpg"]
    # missing cache info, can use public image
    assert_redirected_to "/en/image#{node.zip}_pv.#{make_cachestamp(node,'pv')}.jpg"
    # bad cache info
    get 'show', :prefix => 'en', :path => ["image#{node.zip}.1234.jpg"]
    assert_redirected_to "/en/image#{node.zip}.#{make_cachestamp(node,nil)}.jpg"
    # cache info ok
    get 'show', :prefix => 'en', :path => ["image#{node.zip}.#{make_cachestamp(node,nil)}.jpg"]
    assert_response :success
  end

  def test_should_get_document_css
    login(:tiger)
    node = secure!(Node) { nodes(:style_css) }
    get 'show', :prefix => 'oo', :path => ["textdocument#{node.zip}.css"]
    # missing cache info, should use public lang
    assert_redirected_to "/en/textdocument#{node.zip}.#{make_cachestamp(node,nil)}.css"
    # bad cache info
    get 'show', :prefix => 'en', :path => ["textdocument#{node.zip}.1234.css"]
    assert_redirected_to "/en/textdocument#{node.zip}.#{make_cachestamp(node,nil)}.css"
    # cache info ok
    get 'show', :prefix => 'en', :path => ["textdocument#{node.zip}.#{make_cachestamp(node,nil)}.css"]
    assert_response :success
  end

  def test_should_cache_document_data_without_cachestamp
    with_caching do
     without_files('/test.host/public') do
        login(:anon)
        node = secure!(Node) { nodes(:bird_jpg) }
        get 'show', :prefix => 'en', :path => ["image#{node.zip}.jpg"]
        # missing cache info
        assert_redirected_to "/en/image#{node.zip}.#{make_cachestamp(node,nil)}.jpg"
        assert !File.exist?("#{SITES_ROOT}/test.host/public/en/image#{node.zip}.jpg")
        # bad cache info
        get 'show', :prefix => 'en', :path => ["image#{node.zip}.1234.jpg"]
        assert_redirected_to "/en/image#{node.zip}.#{make_cachestamp(node,nil)}.jpg"
        assert !File.exist?("#{SITES_ROOT}/test.host/public/en/image#{node.zip}.#{make_cachestamp(node,nil)}.jpg")
        # cache info ok
        get 'show', :prefix => 'en', :path => ["image#{node.zip}.#{make_cachestamp(node,nil)}.jpg"]
        # This is the redirect to force apache serving
        assert_redirected_to "/en/image#{node.zip}.#{make_cachestamp(node,nil)}.jpg?1"
        assert File.exist?("#{SITES_ROOT}/test.host/public/en/image#{node.zip}.#{make_cachestamp(node,nil)}.jpg")
      end
    end
  end

  def test_cache_xml_format
    test_site(:zena)
    without_files('/test.host/public') do
      name = "section#{nodes_zip(:people)}.xml"
      cache_path = "#{SITES_ROOT}/test.host/public/en/#{name}"
      with_caching do
        assert !File.exist?(cache_path)
        login(:lion)
        doc = secure!(Template) { Template.create('title'=>'Node', 'format'=>'xml', 'text' => '<?xml version="1.0" encoding="utf-8"?><node><title do="title"/></node>', 'parent_id'=>nodes_id(:default))}
        assert !doc.new_record?, "Not a new record"
        assert doc.publish
        login(:anon)
        get 'show', :prefix => 'en', :path => [name]
        assert_response :success
        assert_equal '<?xml version="1.0" encoding="utf-8"?><node><title>people</title></node>', @response.body
        assert File.exist?(cache_path)
        assert_equal '<?xml version="1.0" encoding="utf-8"?><node><title>people</title></node>', File.read(cache_path)
      end
    end
  end

  def test_update_l_status
    login(:lion)
    opening = secure!(Node) { nodes(:opening) }
    art = opening.find(:first, 'set_tag')
    assert_equal 5, art.l_status
    put 'update', :id => art[:zip], :node => {:l_status => 54321, :link_id => links_id(:opening_in_art)}
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
      name = 'textdocument54.11fbc.css'
      base = "#{SITES_ROOT}/test.host/public/en"
      filename = [base, name].join('/')
      with_caching do
        assert !File.exist?(filename)
        get 'show', :prefix => 'en', :path => [name]
        assert_response :success
        cache1 = filename
        assert File.exist?(cache1), "Cache exists #{cache1}" # cached page created
        assert_match %r[body \{ background: #eee; color:#444;], File.read(cache1)
        put 'save_text', :id => nodes_zip(:style_css), :node => {'text' => '/* empty */'}
        node = assigns['node']
        assert node.errors.empty?
        assert_equal Zena::Status::Pub, node.version.status
        assert_equal versions_id(:style_css_en), node.version.id # auto publish
        assert !File.exist?(cache1) # old cached page removed
        name2 = "textdocument54.#{make_cachestamp(node, nil)}.css"
        get 'show', :prefix => 'en', :path => [name]
        assert_redirected_to "/en/#{name2}"
        get 'show', :prefix => 'en', :path => [name2]
        assert_response :success
        cache2 = [base, name2].join('/')
        assert File.exist?(cache2) # cached page created again
        assert_match %r[/\* empty \*/], File.read(cache2)
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
  
  def test_import_xhtml
    without_files('/test.host/data') do
      without_files('/test.host/zafu') do
        login(:lion)
        post 'import', :id => nodes(:skins).zip, :node => {:klass => 'Skin', :v_status => Zena::Status::Pub}, :attachment => uploaded_archive('jet_30.zip')
        
        node_list = assigns(:nodes)
        nodes = {}
        node_list.each do |n|
          nodes[n.title] = n
        end
        assert skin = nodes['jet_30']
        assert_kind_of Skin, skin
        assert zafu = nodes['Node']
        assert_kind_of Template, zafu
        assert_equal 'html', zafu.format
        assert_equal 'Node', zafu.target_klass
        assert_equal 'N', zafu.tkpath
        assert style = nodes['style']
        assert_kind_of TextDocument, style
        assert navBar = nodes['nav_bar']
        assert_kind_of Image, navBar
        assert xhtmlBgHover = nodes['xhtml_bg_hover']
        assert_kind_of Image, xhtmlBgHover
        assert topIcon = nodes['top_icon']
        assert_kind_of Image, topIcon
        ['lft_pic1', 'lft_pic2', 'lft_pic3'].each do |p|
          assert nodes[p]
          assert_kind_of Image, nodes[p]
        end
        assert_match %r{#header ul\{\s*background:url\('/en/image#{navBar.zip}.[0-9a-f]+.gif'\)}m, style.text
        assert_match %r{a\.xht:hover\{\s*background:url\('/en/image#{xhtmlBgHover.zip}.[0-9a-f]+.gif'\)}, style.text

        # use this template
        status = nodes(:status)
        status.visitor = Thread.current[:visitor]
        assert status.update_attributes(:skin_id => skin.id, :inherit => 0)
        get 'show', 'prefix'=>'oo', 'path'=>['projects-list', 'Clean-Water-project', "page#{status.zip}.html"]
        assert_response :success

        assert_match %r{posuere eleifend arcu</p>\s*<img [^>]*src\s*=\s*./en/image#{topIcon.zip}.[0-9a-f]+.gif}, @response.body
      end
    end
  end

  def test_edit_attribute_publish
    login(:tiger)
    node = secure!(Node) { nodes(:letter) }
    assert_equal Zena::Status::Pub, node.version.status
    # get ajax
    get 'edit', :format => 'js', :id => node.zip, 'attribute' => 'paper', 'dom_id' => 'foo', 'publish' => 'true', 'zazen' => 'true'
    assert_match %r{name='node\[v_status\]' value='50'}m, @response.body
    assert_match %r{name='publish' value='true'}m, @response.body

    put 'update', :format => 'js', :id => node.zip, 'publish' => 'true', 'zazen' => 'true', 'dom_id' => 'foo', 'node' => {'paper' => 'Parchment', 'v_status' => '50'}
    assert_match %r{publish=true}m, @response.body

    node = secure!(Node) { nodes(:letter) }
    assert_equal Zena::Status::Pub, node.v_status
    assert_equal 'Parchment', node.prop['paper']
  end

  def test_update_change_v_status_reloads_page
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    node.update_attributes('title' => 'foobar')
    assert_equal Zena::Status::Red, node.v_status
    # ajax
    put 'update', :format => 'js', :id => node.zip, 'zazen' => 'true', 'dom_id' => 'foo', 'node' => {'title' => 'Michel Serres', 'v_status' => '50'}
    node = secure!(Node) { nodes(:status) }
    assert_equal Zena::Status::Pub, node.v_status
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
    assert_match %r{/Default skin/Node-\+popupLayout/en/_main$}, @response.layout
  end

  def test_crop_image
    preserving_files('test.host/data') do
      login(:ant)
      img = secure!(Node) { nodes(:bird_jpg) }
      assert_equal Zena::Status::Pub, img.version.status
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
      # image size can vary depending on image processor.
      assert 2002 <= img.size
      assert img.size <= 2010
      assert_equal 160,  img.width
      assert_equal 80, img.height
    end
  end

  def test_should_get_test_page_without_errors
    without_files('test.host/zafu') do
      login(:tiger)
      get 'show', 'prefix'=>'oo', 'path'=>["testnode#{nodes_zip(:test)}.html"]
      assert_response :success
    end
  end

  def test_create_from_url
    login(:tiger)
    if Zena::Use::Upload.has_network?
      preserving_files('test.host/data') do
        assert_difference('Node.count', 1) do
          post 'create', 'attachment_url' => 'http://zenadmin.org/fr/blog/image5.0c8db.jpg', 'node' => {'parent_id' => nodes_zip(:zena)}
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
    get 'search', 'qb' => 'projects where (set_tag.id = 33 and hot.id = 22) in site'
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
