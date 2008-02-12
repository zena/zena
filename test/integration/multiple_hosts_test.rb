require "#{File.dirname(__FILE__)}/../test_helper"

class MultipleHostsTest < ActionController::IntegrationTest
  include Zena::Test::Base
  fixtures :nodes, :versions, :users, :groups_users
  
  def test_visitor_host
    anon.get_node(:wiki)
    assert_equal 200, anon.status
    assert_equal 'test.host', anon.assigns(:visitor).site.host
    anon.get_node(:ocean, :host => 'ocean.host')
    assert_equal 'ocean.host', anon.assigns(:visitor).site.host
    Node.connection.execute "UPDATE nodes set zip = 14 where id = 40" # whale
    anon.get "http://ocean.host/en/contact14.html" # zip 14 ==> whale
    assert_equal nodes(:whale)[:id], anon.assigns(:node)[:id]
    anon.get "http://test.host/en/contact14.html"  # zip 14 ==> tiger
    assert_equal nodes(:tiger)[:id], anon.assigns(:node)[:id]
  end
  
  def test_visitor_anon
    anon.get_node(:status)
    assert_kind_of User, anon.assigns(:visitor)
    assert_equal users(:anon).id, anon.assigns(:visitor).id
    anon.get_node(:ocean, :host=>'ocean.host')
    assert_equal users(:incognito).id, anon.assigns(:visitor).id
  end
  
  def test_cache
    without_files('/test.host/public') do
      with_caching do
        path = "/en/projects/cleanWater/page22.html"
        filepath = "#{RAILS_ROOT}/sites/test.host/public#{path}"
        assert !File.exist?(filepath)
        anon.get "http://test.host#{path}"
        assert_equal 200, anon.status
        assert File.exist?(filepath), "Cache file created"
        node = nodes(:status)
        assert_equal 1, CachedPage.count(:conditions => "path like '%page22%'")
        assert_not_equal 0, CachedPage.connection.execute("SELECT COUNT(*) as count_all FROM cached_pages_nodes WHERE node_id = #{node[:id]}").fetch_row[0].to_i
        node.visitor = Thread.current.visitor
        node.sweep_cache
        assert_equal 0, CachedPage.count(:conditions => "path like '%page22%'")
        assert_equal 0, CachedPage.connection.execute("SELECT COUNT(*) as count_all FROM cached_pages_nodes WHERE node_id = #{node[:id]}").fetch_row[0].to_i
        assert !File.exist?(filepath)
      end
    end
  end
  
  def test_index
    anon.get 'http://test.host/en'
    assert_equal nodes(:zena)[:id], anon.assigns(:node)[:id]
    anon.get 'http://ocean.host/en'
    assert_equal nodes(:ocean)[:id], anon.assigns(:node)[:id]
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