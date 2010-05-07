require "#{File.dirname(__FILE__)}/../test_helper"

class MultipleHostsTest < ActionController::IntegrationTest
  # Maybe we can remove all these includes...
  include Zena::Use::Fixtures
  include Zena::Use::TestHelper
  include Zena::Acts::Secure
  include ::Authlogic::TestCase

  def test_visitor_host
    anon.get_node(:wiki)
    assert_equal 200, anon.status
    assert_equal 'test.host', anon.assigns(:visitor).site.host
    anon.get_node(:ocean, :host => 'ocean.host')
    assert_equal 'ocean.host', anon.assigns(:visitor).site.host
    Node.connection.execute "UPDATE nodes set zip = 11114 where id = #{nodes(:ocean_whale)[:id]}" # whale
    Node.connection.execute "UPDATE nodes set zip = 11114 where id = #{nodes(:zena_tiger)[:id]}" # tiger
    anon.get "http://ocean.host/en/contact11114.html" # zip 11114 ==> whale
    assert_equal nodes(:ocean_whale)[:id], anon.assigns(:node)[:id]
    anon.get "http://test.host/en/contact11114.html"  # zip 11114 ==> tiger
    assert_equal nodes(:zena_tiger)[:id], anon.assigns(:node)[:id]
  end

  def test_visitor_anon
    anon.get_node(:status)
    assert_kind_of User, anon.assigns(:visitor)
    assert_equal users(:anon).id, anon.assigns(:visitor).id
    anon.get_node(:ocean, :host=>'ocean.host')
    assert_equal users(:incognito).id, anon.assigns(:visitor).id
  end

  def test_cache
    status_zip = nodes(:zena_status)[:zip]
    without_files('/test.host/public') do
      with_caching do
        path = "/en/projects/cleanWater/page#{status_zip}.html"
        filepath = "#{RAILS_ROOT}/sites/test.host/public#{path}"
        assert !File.exist?(filepath)
        anon.get "http://test.host#{path}"
        assert_equal 200, anon.status
        assert File.exist?(filepath), "Cache file created"
        node = nodes(:zena_status)
        assert_equal 1, CachedPage.count(:conditions => "path like '%page#{status_zip}%'")
        assert_not_equal 0, Zena::Db.fetch_row("SELECT COUNT(*) as count_all FROM cached_pages_nodes WHERE node_id = #{node[:id]}").to_i
        node.visitor = Thread.current[:visitor]
        node.sweep_cache
        assert_equal 0, CachedPage.count(:conditions => "path like '%page#{status_zip}%'")
        assert_equal 0, Zena::Db.fetch_row("SELECT COUNT(*) as count_all FROM cached_pages_nodes WHERE node_id = #{node[:id]}").to_i
        assert !File.exist?(filepath)
      end
    end
  end

  def test_index
    anon.get 'http://test.host/en'
    assert_equal nodes(:zena_zena)[:id], anon.assigns(:node)[:id]
    anon.get 'http://ocean.host/en'
    assert_equal nodes(:ocean_ocean)[:id], anon.assigns(:node)[:id]
  end

  private

  module CustomAssertions
    include Zena::Test::Integration

    def get_node(node_sym=:status, opts={})
      host = opts.delete(:host) || 'test.host'

      @site = Site.find_by_host(host)

      @node = nodes("#{@site.name}_#{node_sym}".to_sym)

      if @node[:id] == @site.root_id
        name = []
      else
        name = "#{@node.class.to_s.downcase}#{@node[:zip]}.html"
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