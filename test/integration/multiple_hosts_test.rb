require "#{File.dirname(__FILE__)}/../test_helper"

class MultipleHostsTest < ActionController::IntegrationTest
  fixtures :nodes, :versions, :users, :groups_users
  
  def test_visitor_host
    anon.get_node(:status)
    assert_equal 'www.example.com', anon.assigns(:visitor).host
    anon.get_node(:status, :host=>'other.host')
    assert_equal 'other.host', anon.assigns(:visitor).host
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
    def visitor
      @visitor ||= begin
        if @response && session && session[:user]
          user = User.find(self[:user])
        else
          user = anonymous_user
        end 
        # we do not want the password hanging around if not necessary, even hashed
        user[:password] = nil
        user
      end
    end
    
    def get_node(node_sym=:status, opts={})
      @node = secure(Node) { nodes(node_sym) }
      if @node[:id] == ZENA_ENV[:root_id]
        path = []
      else
        path = @node.basepath.split('/')
        unless @node[:custom_base]
          path += ["#{@node.class.to_s.downcase}#{@node[:id]}.html"]
        end
      end
      prefix = visitor.anon? ? 'en' : AUTHENTICATED_PREFIX
      if opts[:host]
        host! opts[:host]
        opts.delete(:host)
      end
      get 'show', {:path=>path, :prefix=>prefix}.merge(opts)
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