require "#{File.dirname(__FILE__)}/../test_helper"

class MultipleHostsTest < ActionController::IntegrationTest
  fixtures :nodes, :versions, :users, :groups_users
  
  def test_visitor_host
    anon.get_node(:status)
    assert_equal 200, anon.status
    assert_equal 'test.host', anon.assigns(:visitor).site.host
    host! 'ocean.host'
    anon.get '/en'
    assert_equal 'ocean.host', anon.assigns(:visitor).site.host
  end
  
  def test_visitor_anon
    anon.get_node(:status)
    assert_kind_of User, anon.assigns(:visitor)
    assert_equal users(:anon).id, anon.assigns(:visitor).id
    anon.get_node(:ocean, :host=>'ocean.host')
    assert_equal users(:incognito).id, anon.assigns(:visitor).id
  end
  
  private
  def with_caching
    @perform_caching_bak = ApplicationController.perform_caching
    ApplicationController.perform_caching = true
    yield
    ApplicationController.perform_caching = @perform_caching_bak
  end
  
  
  module CustomAssertions
    include Zena::Test::Integration
    
    def get_node(node_sym=:status, opts={})
      @node = nodes(node_sym)
      host! opts[:host] || 'test.host'
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
      url = "#{prefix}/#{path.join('/')}"
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