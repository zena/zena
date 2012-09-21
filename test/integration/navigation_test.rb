require 'test_helper'

class NavigationTest < Zena::Integration::TestCase

  def test_authorize
    get 'http://test.host/'
    assert_redirected_to 'http://test.host/en'
    follow_redirect!
    assert_response :success

    # 1. site forces authentication
    Site.connection.execute "UPDATE sites SET authentication = 1 WHERE id = #{sites_id(:zena)}"
    get 'http://test.host/'
    assert_redirected_to 'http://test.host/login'

    post 'http://test.host/session', :login=>'tiger', :password=>'tiger'
    assert_redirected_to "http://test.host/"
    follow_redirect!
    assert_redirected_to "http://test.host/oo"

    # 2. navigating out of '/oo' but logged in and format is not data
    get 'http://test.host/fr'
    assert_redirected_to 'http://test.host/oo'
    follow_redirect!
    assert_response :success
    get 'http://test.host/fr/textdocument54.css?1144713600' # data with timestamp
    assert_response :success
  end

  def test_should_not_redirect_to_css

    # 1. site forces authentication
    Site.connection.execute "UPDATE sites SET authentication = 1 WHERE id = #{sites_id(:zena)}"
    get 'http://test.host/en/textdocument53.css' # style_css
    assert_redirected_to 'http://test.host/login'

    post 'http://test.host/session', :login=>'tiger', :password=>'tiger'
    assert_redirected_to "http://test.host/oo"
  end

  context 'Asset rendering' do
    setup do
      post 'http://test.host/session', :login=>'tiger', :password=>'tiger'
      @visitor = users(:tiger)
      Thread.current[:visitor] = nil
    end

    context 'with valid http auth' do
      setup do
        @headers = {
          'HTTP_AUTHORIZATION' => 'Basic ' + Base64::encode64("#{@visitor.id}:#{@visitor.persistence_token}")
        }
      end

      subject do
        [
          "http://test.host:1234/oo/project19.html",
          {},
          @headers
        ]
      end

      should 'set host and login wth given user' do
        reset!
        get *subject
        assert_response :success
        assert users_id(:tiger), visitor.id
        assert_match %r{Secret}, response.body
      end

      context 'but invalid host' do
        subject do
          [
            "http://ocean.host:1234/oo/project19.html",
            {},
            @headers
          ]

        end

        should 'redirect to login' do
          reset!
          get *subject
          assert_response :redirect
          assert_redirected_to 'http://ocean.host/login'
          assert_equal users_id(:incognito), visitor.id
        end
      end # but invalid host
    end # with a valid http auth
  end # With render_token in url

  context 'Rescue template rendering' do
    setup do
      post 'http://test.host/session', :login=>'lion', :password=>'lion'
      get  'http://test.host/rescue'
      @visitor = users(:tiger)
      Thread.current[:visitor] = nil
    end

    should 'render home page' do
      get 'http://test.host/oo'
      assert_response :success
    end
  end # Rescue template rendering

  def test_out_of_oo_custom_base_set_lang
    post 'http://test.host/session', :login => 'tiger', :password => 'tiger'
    assert_redirected_to "http://test.host/oo"
    # 2. navigating out of '/oo' but logged in and format is not data, custom_base url (format not in path)
    assert_equal 'en', session[:lang]
    get 'http://test.host/fr/page18.html'
    assert_redirected_to 'http://test.host/oo/page18.html'
    assert_equal 'fr', session[:lang]
    follow_redirect!
    assert_response :success
  end

  context 'Selecting lang' do
    context 'from HTTP_ACCEPT_LANGUAGE' do
      context 'with invalid languages' do
        setup do
          Site.connection.execute "UPDATE sites SET languages = 'fr,en,es' WHERE id = #{sites_id(:zena)}"
        end

        should 'use q for sorting' do
          get 'http://test.host/', {}, {'HTTP_ACCEPT_LANGUAGE' => 'de-DE,fr-FR;q=0.8,es;q=0.9'}
          assert_redirected_to 'http://test.host/es'
        end

        should 'use q on lang group and skip invalid' do
          get 'http://test.host/', {}, {'HTTP_ACCEPT_LANGUAGE' => 'de-DE,fr-FR;q=0.8,es;q=0.3'}
          assert_redirected_to 'http://test.host/fr'
        end
      end # with invalid languages

      context 'with valid languages' do
        setup do
          Site.connection.execute "UPDATE sites SET languages = 'fr,de,en,es' WHERE id = #{sites_id(:zena)}"
        end

        should 'use first from group' do
          get 'http://test.host/', {}, {'HTTP_ACCEPT_LANGUAGE' => 'de-DE,fr-FR;q=0.8,es;q=0.3'}
          assert_redirected_to 'http://test.host/de'
        end

        should 'set session lang after redirect' do
          get 'http://test.host/', {}, {'HTTP_ACCEPT_LANGUAGE' => 'de-DE,fr-FR;q=0.8,es;q=0.3'}
          assert_redirected_to 'http://test.host/de'
          assert_equal 'de', session[:lang]
        end
      end # with valid languages

      context 'with prefix' do
        should 'use prefix' do
          get 'http://test.host/es', {}, {'HTTP_ACCEPT_LANGUAGE' => 'de-DE,fr-FR;q=0.8,es;q=0.3'}
          assert_response :success
          assert_equal 'es', session[:lang]
        end
      end # with prefix

      context 'with lang' do
        should 'use lang' do
          get 'http://test.host?lang=es', {}, {'HTTP_ACCEPT_LANGUAGE' => 'de-DE,fr-FR;q=0.8,es;q=0.3'}
          assert_redirected_to 'http://test.host/es'
          assert_equal 'es', session[:lang]
        end
      end # with lang

      context 'with lang and prefix' do
        should 'use lang' do
          get 'http://test.host/es?lang=fr', {}, {'HTTP_ACCEPT_LANGUAGE' => 'de-DE,fr-FR;q=0.8,es;q=0.3'}
          assert_redirected_to 'http://test.host/fr'
          assert_equal 'fr', session[:lang]
        end
      end # with lang and prefix

      context 'with lang and authenticated prefix' do
        setup do
          post 'http://test.host/session', :login => 'tiger', :password => 'tiger'
        end

        should 'use lang' do
          get 'http://test.host/oo?lang=fr', {}, {'HTTP_ACCEPT_LANGUAGE' => 'de-DE,fr-FR;q=0.8,es;q=0.3'}
          assert_redirected_to 'http://test.host/oo'
          assert_equal 'fr', session[:lang]
        end
      end # with lang and authenticated prefix
    end # from HTTP_ACCEPT_LANGUAGE


    context 'without clues' do
      should 'use session' do
        get 'http://test.host/fr'
        assert_response :success
        assert_equal 'fr', session[:lang]
        get 'http://test.host'
        assert_redirected_to 'http://test.host/fr'
      end
    end # without clues

    context 'with lang on bad url' do
      should 'set lang from url' do
        get 'http://test.host/de/foobar'
        assert_response :not_found
        assert_equal 'de', session[:lang]
        assert_equal 'de', visitor.lang
      end
    end
  end # Selecting lang

  context 'In an intranet' do
    setup do
      # Only lion is in the 'admin' group
      $_test_site = 'zena'
      Zena::Db.execute "UPDATE nodes SET rgroup_id = #{groups_id(:admin)}, wgroup_id = #{groups_id(:admin)}, dgroup_id = #{groups_id(:admin)}"
    end

    context 'an anonymous user' do
      should 'not raise not found on login' do
        get 'http://test.host/login'
        assert_response :success
        assert_match %r{/\$default/Node-\+login}, @response.rendered[:template].to_s
      end
    end # an anonymous user

    context 'a visitor without group access' do
      setup do
        post 'http://test.host/session', :login=>'ant', :password=>'ant'
      end

      should 'raise not found on root' do
        get 'http://test.host/oo'
        assert_response :missing
      end

      context 'using acl' do
        setup do
          Zena::Db.execute "UPDATE users SET use_acls = #{Zena::Db.quote(true)} WHERE id = #{users_id(:ant)}"
        end

        should 'redirect to user page on root not found' do
          get 'http://test.host/oo'
        end
      end # using acl
    end # a visitor without group access
  end # An intranet

  def test_set_lang_authenticated
    post 'http://test.host/session', :login=>'lion', :password=>'lion'
    get 'http://test.host/oo/page32.html?lang=fr'
    assert_redirected_to 'http://test.host/oo/page32.html'
    assert_equal 'fr', visitor.lang
  end

  def test_set_lang_out_of_nodes
    post 'http://test.host/session', :login=>'lion', :password=>'lion'
    get 'http://test.host/users?lang=fr'
    assert_redirected_to 'http://test.host/users'
    assert_equal 'fr', visitor.lang
  end


  def test_set_lang_with_login
    post 'http://test.host/session', :login=>'tiger', :password=>'tiger'
    follow_redirect!
    assert_response :success
    assert_equal 'en', session[:lang]
    get 'http://test.host/oo?lang=fr'
    assert_redirected_to 'http://test.host/oo'
    follow_redirect!
    assert_response :success
    assert_equal 'fr', session[:lang]
  end

  context 'With new languages defined' do
    setup do
      login(:lion)
      assert visitor.site.update_attributes(:languages => 'en,fr,cn')
    end

    should 'compile templates' do
      post 'http://test.host/session', :login=>'lion', :password=>'lion'
      get 'http://test.host/oo?lang=cn'
      assert_redirected_to 'http://test.host/oo'
      follow_redirect!
      assert_response :success
    end
  end

  context 'On a page with custom base' do
    setup do
      login(:lion)
      assert_equal users(:lion).id, visitor.id
      # add a publication in 'fr'
      visitor.lang = 'fr'
      node = secure!(Node) { nodes(:cleanWater) }
      node.update_attributes(:title => 'Eau propre', :v_status => Zena::Status::Pub)
      logout
    end

    subject do
      'http://test.host/projects-list/Clean-Water-project'
    end

    should 'get response' do
      get subject
      assert_redirected_to '/en/projects-list/Clean-Water-project'
      follow_redirect!
      assert_response :success
    end

    context 'in the wrong language' do
      should 'redirect to translated page' do
        # Set 'fr' session lang
        get 'http://test.host/fr'
        get subject
        assert_redirected_to '/fr/projects-list/Clean-Water-project'
        follow_redirect!
        assert_redirected_to '/fr/projects-list/Eau-propre'
        follow_redirect!
        assert_response :success
      end
    end # in the wrong language

    context 'with a mode' do
      setup do
        login(:lion)
        secure(Template) { Template.create(:parent_id => nodes_id(:default), :title => 'Project-changes.zafu', :v_status => Zena::Status::Pub, :text => 'nothing ever changes in "<r:title/>"') }
      end

      subject do
        'http://test.host/en/projects-list/Clean-Water-project_changes'
      end

      should 'get response' do
        get subject
        assert_response :success
        assert_equal 'nothing ever changes in "Clean Water project"', response.body
      end
    end # with a mode

  end # On a page with custom base

  def test_url_with_custom_base
    get 'http://test.host/en/projects-list/Clean-Water-project'
    assert_response :success
  end

  def test_nodes_redirect
    get 'http://test.host/nodes/30'
    assert_redirected_to 'http://test.host/en/image30.html'
    follow_redirect!
    assert_response :success
  end

  def test_url_without_lang_redirect
    get 'http://test.host/blog29.html'
    assert_redirected_to 'http://test.host/en/blog29.html'
    follow_redirect!
    assert_response :success
  end

  def test_url_without_lang_redirect_keeps_url_params
    get 'http://test.host/blog29.html?page=2'
    assert_redirected_to 'http://test.host/en/blog29.html?page=2'
    follow_redirect!
    assert_response :success
  end

  def test_url_bad_class_redirect_keeps_url_params
    get 'http://test.host/en/page29.html?page=2'
    assert_redirected_to 'http://test.host/en/blog29.html?page=2'
    follow_redirect!
    assert_response :success
  end

  def test_url_by_zip_without_lang_redirect
    get 'http://test.host/29'
    assert_redirected_to 'http://test.host/en/29'
    follow_redirect!
    assert_redirected_to 'http://test.host/en/blog29.html'
    follow_redirect!
    assert_response :success
  end

  def test_url_by_path_without_lang_redirect
    get 'http://test.host/people'
    assert_redirected_to 'http://test.host/en/people'
    follow_redirect!
    assert_redirected_to 'http://test.host/en/section12.html'
    follow_redirect!
    assert_response :success
  end

  def test_bad_url
    get 'http://test.host/en/node1.html'
    assert_response :missing
  end

  def test_bad_url_without_notFound_template
    $_test_site = 'zena'
    Node.connection.execute "UPDATE nodes SET kpath='N' where id = #{nodes_id(:Node_not_found_zafu)}"
    post 'http://test.host/session', :login=>'tiger', :password=>'tiger'
    get 'http://test.host/oo/node1.html'
    assert_response :missing
  end

  def test_bad_zip
    get 'http://test.host/1'
    assert_redirected_to 'http://test.host/en/1'
    follow_redirect!
    assert_response :missing
  end
  
  def test_cache_root
    without_files('test.host/public') do
      preserving_files('/test.host/data') do
        with_caching do
          login(:anon)
          root_path = "#{SITES_ROOT}#{visitor.site.public_path}/en.html"
          assert !File.exists?(root_path), "No cached file yet"
          get 'http://test.host/en'
          assert_response :success
          
          # en.html exist
          assert File.exists?(root_path), "Cached file created"
        end
      end
    end
  end
  
  def test_cache_query_string
    without_files('test.host/public') do
      preserving_files('/test.host/data') do
        with_caching do
          login(:anon)
          base  = "#{SITES_ROOT}#{visitor.site.public_path}"
          good = {
            '/en?p=1' => '/enp=1.html',
            '/en?p=2' => '/enp=2.html',
            '/en?p=9' => '/enp=9.html',
            '/en/blog29.html?p=2' => '/en/blog29.htmlp=2.html',
          }
          
          bad = {
            '/en?x=1'  => '/en.htmlx=1.html',
            '/en?ap=2' => '/en.htmlap=2.html',
            '/en?p=99' => '/en.htmlp=99.html',
            '/en/blog29.html?p=21' => '/en/blog29.htmlp=21.html',
            '/en/blog29.html?x=2'  => '/en/blog29.htmlx=2.html',
          }
          
          good.each do |p, c|
            assert !File.exists?(base + c), "No cached file yet"
            get "http://test.host#{p}"
            assert_response :success
            assert File.exists?(base + c), "Cached file created"
          end
          
          bad.each do |p, c|
            assert !File.exists?(base + c), "No cached file yet"
            get "http://test.host#{p}"
            assert_response :success
            assert !File.exists?(base + c), "No cached file created"
          end
        end
      end
    end
  end

  def test_should_not_change_session_lang_on_login
    get 'http://test.host/'
    assert_redirected_to 'http://test.host/en'
    assert_equal 'en', session[:lang]
    get 'http://test.host/oo'
    assert_redirected_to 'http://test.host/login'
    post 'http://test.host/session', :login => 'ant', :password => 'ant'
    assert_redirected_to 'http://test.host/oo'
    # should not change session lang
    assert_equal 'en', session[:lang]

    # update visitor lang (as if changed through preferences)
    User.connection.execute "UPDATE users SET lang = 'de' WHERE id = #{users_id(:ant)} and site_id = #{sites_id(:zena)}"
    get 'http://test.host/oo'
    assert_equal 'de', session[:lang]

    get 'http://test.host/fr'
    assert_redirected_to 'http://test.host/oo'
    assert_equal 'fr', session[:lang]
    assert_equal 'fr', User.find(users_id(:ant)).lang
  end

  def test_show_with_mode
    get "http://test.host/en/section12_changes.html"
    assert_response :missing # people is not rendered with 'wiki' mode where 'changes' is defined.
    get "http://test.host/en/blog29_changes.html"
    assert_response :success
    get 'http://test.host/en/section12_index.html'
    assert_response :missing
    get 'http://test.host/en/section12_+index.html'
    assert_response :missing
  end

  def test_show_bad_mode
    get 'http://test.host/en/section12_std.html'
    assert_response :missing
  end

  def test_show_with_internal_mode
    get 'http://test.host/en/section12_+index.html'
    assert_response :missing
  end

  private

    module CustomAssertions
      include Zena::Test::Integration

      def get_node(node_sym=:status, opts={})
        @node = nodes(node_sym)
        host = opts[:host] || 'test.host'
        opts.delete(:host)

        @site = Site.find_by_host(host)
        if @node[:id] == @site.root_id
          path = []
        else
          path = @node.basepath.split('/')
          unless @node[:custom_base]
            path += ["#{@node.class.to_s.downcase}#{@node[:id]}.html"]
          end
        end
        prefix = (!request || session[:user] == @site.anon_id) ? 'en' : AUTHENTICATED_PREFIX
        url = "http://#{host}/#{prefix}/#{path.join('/')}"
        puts "get #{url}"
        get url
      end
    end

    # We use test_helper's login
    # def login(user = nil)
    #   open_session do |sess|
    #     sess.extend(CustomAssertions)
    #     if user
    #       sess.post 'http://test.host/session', :login=>user.to_s, :password=>user.to_s
    #       sess.follow_redirect!
    #     end
    #   end
    # end
    def logout
      @visitor = nil
      Thread.current[:visitor] = nil
    end

    def anon
      @anon ||= open_session do |sess|
        sess.extend(CustomAssertions)
      end
    end

end