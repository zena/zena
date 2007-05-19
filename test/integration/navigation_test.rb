require "#{File.dirname(__FILE__)}/../test_helper"

class NavigationTest < ActionController::IntegrationTest
  include Zena::Test::Base
  
  def test_authorize
    get 'http://test.host/'
    assert_redirected_to 'http://test.host/en'
    follow_redirect!
    assert_response :success
    
    # 1. site forces authentication 
    Site.connection.execute "UPDATE sites SET authentication = 1 WHERE id = 1" # test.host
    get 'http://test.host/'
    assert_redirected_to 'http://test.host/login'
    
    reset!
    post 'http://test.host/session', :login=>'tiger', :password=>'tiger'
    assert_redirected_to 'http://test.host/users/4'
    
    # 2. navigating out of '/oo' but logged in and format is not data
    get 'http://test.host/fr'
    assert_redirected_to 'http://test.host/oo'
    follow_redirect!
    assert_response :success
    get 'http://test.host/fr/textdocument53.css' # data
    assert_response :success
  end
  
  def test_set_lang
    Site.connection.execute "UPDATE sites SET languages = 'fr,en,es' WHERE id = 1" # test.host
    get 'http://test.host/', {}, {'HTTP_ACCEPT_LANGUAGE' => 'de-DE,fr-FR;q=0.8,es;q=0.9'}
    assert_redirected_to 'http://test.host/es'
    follow_redirect!
    assert_response :success
    get 'http://test.host/', {}, {'HTTP_ACCEPT_LANGUAGE' => 'de-DE,fr-FR;q=0.8,es;q=0.9'}
    assert_redirected_to 'http://test.host/es'
    reset!
    get 'http://test.host/', {}, {'HTTP_ACCEPT_LANGUAGE' => 'de-DE,fr-FR;q=0.8,es;q=0.3'}
    assert_redirected_to 'http://test.host/fr'
    
    Site.connection.execute "UPDATE sites SET languages = 'fr,de,en,es' WHERE id = 1" # test.host
    reset!
    get 'http://test.host/', {}, {'HTTP_ACCEPT_LANGUAGE' => 'de-DE,fr-FR;q=0.8,es;q=0.3'}
    assert_redirected_to 'http://test.host/de'
    follow_redirect!
    assert_response :success
    get 'http://test.host/es'
    assert_response :success
    assert_equal 'es', session[:lang]
    get 'http://test.host/en'
    assert_response :success
    assert_equal 'en', session[:lang]
    get 'http://test.host/en?lang=es'
    assert_redirected_to 'http://test.host/es'
    follow_redirect!
    assert_response :success
    assert_equal 'es', session[:lang]
    get 'http://test.host/nodes/29/edit'
    assert_response :success
  end
  
  def test_set_lang_with_login
    post 'http://test.host/session', :login=>'tiger', :password=>'tiger'
    assert_redirected_to 'http://test.host/users/4'
    follow_redirect!
    assert_response :success
    assert_equal 'en', session[:lang]
    get 'http://test.host/oo?lang=fr'
    assert_redirected_to 'http://test.host/oo'
    follow_redirect!
    assert_response :success
    assert_equal 'fr', session[:lang]
  end
  
  def test_nodes_redirect
    get 'http://test.host/nodes/30'
    assert_redirected_to 'http://test.host/en/image30.html'
    follow_redirect!
    assert_response :success
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
      sess.extend(CustomAssertions)
      if user
        sess.post 'http://test.host/session', :login=>user.to_s, :password=>user.to_s
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