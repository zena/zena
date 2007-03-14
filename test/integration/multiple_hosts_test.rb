require "#{File.dirname(__FILE__)}/../test_helper"

class MultipleHostsTest < ActionController::IntegrationTest
  include Zena::Test::Base
  fixtures :nodes, :versions, :users, :groups_users
  
  def test_visitor_host
    anon.get_node(:status)
    assert_equal 200, anon.status
    assert_equal 'test.host', anon.assigns(:visitor).site.host
    anon.get 'http://ocean.host/en'
    assert_equal 'ocean.host', anon.assigns(:visitor).site.host
  end
  
  def test_visitor_anon
    anon.get_node(:status)
    assert_kind_of User, anon.assigns(:visitor)
    assert_equal users(:anon).id, anon.assigns(:visitor).id
    anon.get_node(:ocean, :host=>'ocean.host')
    assert_equal users(:incognito).id, anon.assigns(:visitor).id
  end
  
  def test_cache
    without_files("sites") do
      with_caching do
        path = "/en/projects/cleanWater/page11.html"
        filepath = "#{RAILS_ROOT}/sites/test.host/public#{path}"
        assert !File.exist?(filepath)
        anon.get "http://test.host#{path}"
        assert_equal 200, anon.status
        assert File.exist?(filepath), "Cache file created"
        node = nodes(:status)
        assert_equal 1, CachedPage.count
        assert_not_equal 0, CachedPage.connection.execute("SELECT COUNT(*) as count_all FROM cached_pages_nodes").fetch_row[0].to_i
        node.sweep_cache
        assert_equal 0, CachedPage.count
        assert_equal 0, CachedPage.connection.execute("SELECT COUNT(*) as count_all FROM cached_pages_nodes").fetch_row[0].to_i
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

  def login(user = nil)
    open_session do |sess|
      @node = secure(Node) { nodes(node_sym) }
      sess.extend(CustomAssertions)
      if user
        sess.post 'login', :user=>{:login=>user.to_s, :password=>user.to_s}
        assert_equal users_id(user), sess.session[:user]
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