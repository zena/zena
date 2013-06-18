require "#{File.dirname(__FILE__)}/../test_helper"

class MultipleHostsTest < ActionController::IntegrationTest
  # Maybe we can remove all these includes...
  include Zena::Use::Fixtures
  include Zena::Use::TestHelper
  include Zena::Acts::Secure
  include ::Authlogic::TestCase

  def nodes(site, fixture)
    $_test_site = site.to_s
    super(fixture)
  end

  def test_visitor_host
    anon.get_node(:wiki)
    assert_equal 200, anon.status
    assert_equal 'test.host', visitor.site.host
    anon.get_node(:ocean, :host => 'ocean.host')
    assert_equal 'ocean.host', visitor.site.host
    Node.connection.execute "UPDATE nodes set zip = 11114 where id = #{nodes(:ocean, :whale)[:id]}" # whale
    Node.connection.execute "UPDATE nodes set zip = 11114 where id = #{nodes(:zena, :tiger)[:id]}" # tiger
    anon.get "http://ocean.host/en/contact11114.html" # zip 11114 ==> whale
    assert_equal nodes(:ocean, :whale)[:id], anon.assigns(:node)[:id]
    anon.get "http://test.host/en/contact11114.html"  # zip 11114 ==> tiger
    assert_equal nodes(:zena, :tiger)[:id], anon.assigns(:node)[:id]
  end

  def test_visitor_anon
    anon.get_node(:status)
    assert_kind_of User, visitor
    assert_equal users(:anon).id, visitor.id
    anon.get_node(:ocean, :host=>'ocean.host')
    assert_equal users(:incognito).id, visitor.id
  end

  def test_cache
    # We need the visitor to load VirtualClass cache.
    anon_user = users(:anon)
    setup_visitor(anon_user, anon_user.site)
    node_zip = nodes(:zena, :people).zip
    Thread.current[:visitor] = nil
    
    without_files('/test.host/public') do
      with_caching do
        path = "/en/section#{node_zip}.html"
        filepath = "#{RAILS_ROOT}/sites/test.host/public#{path}"
        assert !File.exist?(filepath)
        anon.get "http://test.host#{path}"
        assert_equal 200, anon.status
        assert File.exist?(filepath), "Cache file created"
        node = nodes(:zena, :people)
        assert_equal 1, CachedPage.count(:conditions => "path like '%section#{node_zip}%'")
        assert_not_equal 0, Zena::Db.fetch_attribute("SELECT COUNT(*) as count_all FROM cached_pages_nodes WHERE node_id = #{node[:id]}").to_i
        node.visitor = Thread.current[:visitor]
        node.sweep_cache
        assert_equal 0, CachedPage.count(:conditions => "path like '%section#{node_zip}%'")
        assert_equal 0, Zena::Db.fetch_attribute("SELECT COUNT(*) as count_all FROM cached_pages_nodes WHERE node_id = #{node[:id]}").to_i
        assert !File.exist?(filepath)
      end
    end
  end

  def test_index
    anon.get 'http://test.host/en'
    assert_equal nodes(:zena, :zena)[:id], anon.assigns(:node)[:id]
    anon.get 'http://ocean.host/en'
    assert_equal nodes(:ocean, :ocean)[:id], anon.assigns(:node)[:id]
  end

  private

  module CustomAssertions
    include Zena::Test::Integration

    def get_node(node_sym=:status, opts={})
      host = opts.delete(:host) || 'test.host'

      @site = Site.find_by_host(host)

      @node = nodes(@site.name, node_sym)

      if @node[:id] == @site.root_id
        name = []
      else
        name = case node_sym
        when :wiki
          'blog29.html'
        when :status
          'page22.html'
        else
          raise 'Please set page in get_node.'
        end
      end
      prefix = (!request || session[:user] == @site.anon_id) ? 'en' : AUTHENTICATED_PREFIX
      url = "http://#{host}/#{prefix}/#{name}"
      get url
    end
  end

  def login(user = nil)
    open_session do |sess|
      sess.extend(CustomAssertions)
      if user
        sess.post 'login', :user=>{:login=>user.to_s, :password=>user.to_s}
        assert_equal users(user)[:id], sess.response.session[:user]
        assert sess.redirect?
        sess.follow_redirect!
      end
    end
  end

  def anon
    @anon ||= open_session do |sess|
      sess.extend(CustomAssertions)
    end
  end
end