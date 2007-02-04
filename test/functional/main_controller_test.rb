require File.dirname(__FILE__) + '/../test_helper'
require 'main_controller'

# Re-raise errors caught by the controller.
class MainController; def rescue_action(e) raise e end; end

class MainControllerTest < Test::Unit::TestCase
  include ZenaTestController
  
  def setup
    super
    @controller = MainController.new
    init_controller
  end
  
  def test_index
    assert_routing '/en', {:controller=>'main', :action=>'index', :prefix=>'en'}
    assert_routing '/',   {:controller=>'main', :action=>'redirect'}
    get 'index', :prefix=>'en'
    assert_response :success
    assert_template 'index'
  end
  
  def test_render_and_cache
    get 'index'
    assert assigns(:node)
    assert assigns(:project)
    # test send inline document if kind_of?(Document)
    puts "test todo"
    # page caching is tested in Integration Tests
  end
  
  def test_authorize_true
    bak = ZENA_ENV[:authorize]
    ZENA_ENV[:authorize] = true
    get 'index'
    assert_redirected_to :controller=>'login', :action=>'login'
    ZENA_ENV[:authorize] = bak
  end
  
  def test_authorize_false_but_prefix
    bak = ZENA_ENV[:authorize]
    ZENA_ENV[:authorize] = false
    get 'index', :prefix=>AUTHENTICATED_PREFIX
    assert_redirected_to :controller=>'login', :action=>'login'
    ZENA_ENV[:authorize] = bak
  end
  
  def test_authorize_false
    bak = ZENA_ENV[:authorize]
    ZENA_ENV[:authorize] = false
    get 'index'
    assert_response :success
    ZENA_ENV[:authorize] = bak
  end
  
  def test_show
    assert_routing '/en/node19', {:controller=>'main', :action=>'show', :prefix=>'en', :path=>['node19']}
    get 'show', :path=>['node19'], :prefix=>'en'
    assert_response :success
    assert_template 'wiki'
  end
  
  def test_show_redirect
    assert_routing '/en/node12', {:controller=>'main', :action=>'show', :prefix=>'en', :path=>['node12']}
    get 'show', :path=>['node12'], :prefix=>'en'
    assert_response :redirect
    assert_redirected_to :controller=>'main', :action=>'show', :prefix=>'en', :path=>['cleanWater', 'node12']
  end
  
  def test_show_redirect
    assert_routing '/en/bidule', {:controller=>'main', :action=>'show', :path=>['bidule'], :prefix=>'en'}
    get 'show', :path=>['bidule'], :prefix=>'en'
    assert_redirected_to not_found_url
  end
  
  def test_redirect
    assert_routing '/projects', {:controller=>'main', :action=>'redirect', :path=>['projects']}
    get 'redirect', :path=>['projects']
    assert_redirected_to :action=>'show', :prefix=>'en'
    get 'show',     :path=>['projects'],  :prefix=>'en'
    assert_response :success
    assert_template 'default'
  end
  
  def test_redirect_twice
    assert_routing '/bidule', {:controller=>'main', :action=>'redirect', :path=>['bidule']}
    get 'redirect', :path=>['bidule']
    assert_redirected_to :action=>'show', :prefix=>'en'
    get 'show',     :path=>['bidule'],  :prefix=>'en'
    assert_redirected_to not_found_url
  end
  
  def test_not_found
    assert_routing '404', {:controller=>'main', :action=>'not_found'}
    get 'not_found'
    assert_response :success
    assert_template 'not_found'
  end
  
  def test_check_url
    login
    get 'show', :path=>['projects'], :prefix=>'en'
    assert_redirected_to :action => 'show', :prefix=>AUTHENTICATED_PREFIX
    logout
    get 'show', :path=>['projects'], :prefix=>'en'
    assert_response :success
  end
  
  def test_su_views_private_pages
    login(:su)
    get 'show', :path=>['people', 'ant', 'myLife'], :prefix=>AUTHENTICATED_PREFIX
    assert_response :success
  end
  
  def test_cannot_view_private_pages
    get 'show', :path=>['people', 'ant', 'myLife'], :prefix=>'en'
    assert_redirected_to not_found_url
    login(:lion)
    get 'show', :path=>['people', 'ant', 'myLife'], :prefix=>AUTHENTICATED_PREFIX
    assert_redirected_to not_found_url
  end
  
  def test_can_view_own_private_pages
    login(:ant)
    get 'show', :path=>['people', 'ant', 'myLife'], :prefix=>AUTHENTICATED_PREFIX
    assert_response :success
  end
  
  def test_set_env_su_bgcolor
    login(:su)
    get 'index', :prefix=>AUTHENTICATED_PREFIX
    assert_tag :body, :attributes=> { :style => "background:#600;"}
  end
  
  def test_set_env_change_lang
    get 'show', :path=>['projects'], :prefix=>'en', :lang=>'fr'
    assert_redirected_to :prefix=>'fr'
    assert_equal session[:lang], 'fr'
  end
  
  def test_set_env_change_bad_lang
    get 'show', :path=>['projects'], :prefix=>'en', :lang=>'io'
    assert_redirected_to :prefix=>'en'
    assert_equal session[:lang], 'en'
    assert_equal flash[:notice], "The requested language is not available."
  end
  
  def test_set_env_bad_lang
    get 'show', :path=>['projects'], :prefix=>'io', :lang=>'io'
    assert_redirected_to :prefix=>'en'
    assert_equal 'en', session[:lang]
  end
  
  def test_set_env_prefix_lang
    get 'show', :path=>['projects'], :prefix=>'fr'
    assert_equal 'fr', session[:lang]
  end
  
  def test_set_env_cannot_translate
    get 'show', :path=>['projects'], :prefix=>'fr', :translate=>'on'
    assert_redirected_to 'fr/projects'
    assert_nil session[:translate]
  end
  
  def test_set_env_translate
    login(:lion)
    get 'show', :path=>['projects'], :prefix=>prefix, :translate=>'on'
    assert_redirected_to "#{prefix}/projects"
    assert session[:translate]
    get 'show', :path=>['projects'], :prefix=>prefix
    assert_tag :tag => 'div', :attributes => { :id => 'trans_17' } # Pages translation
    get 'show', :path=>['projects'], :prefix=>prefix, :translate=>'off'
    assert_redirected_to "#{prefix}/projects"
    get 'show', :path=>['projects'], :prefix=>prefix
    assert_no_tag :tag => 'div', :attributes => { :id => 'trans_17' }
    assert_nil session[:translate]
  end
  
  def test_view_page_without_edition
    login(:ant)
    get 'show', :path=>['projects', 'cleanWater', 'crocodiles'], :prefix=>AUTHENTICATED_PREFIX
    assert_redirected_to '404'
    login(:tiger)
    get 'show', :path=>['projects', 'cleanWater', 'crocodiles'], :prefix=>AUTHENTICATED_PREFIX
    assert_response :success
  end
  
  def test_view_page_without_traduction
    login(:ant)
    session[:lang] = 'ru'
    get 'show', :path=>['projects'], :prefix=>AUTHENTICATED_PREFIX
    assert_response :success
    assert_equal 2, assigns(:node).pages.size
    assert_tag :span, :attributes=>{:class=>'wrong_lang'}
  end
  
  # test partials
  
  def test__pages
    login(:tiger)  
    get 'show', :path=>['projects'], :prefix=>prefix
    assert_response :success
    assert_template 'templates/default'
    assert_tag :div, :attributes=>{:id=>'pages'}
    assert_tag :ul, :attributes=>{:class=>'list', :id=>"pages_list"}
    assert_tag :li, :attributes=>{:class=>'btn_add', :id=>"add_page"}
  end
  
  def test__documents
    login(:tiger)
    get 'show', :path=>['projects'], :prefix=>prefix
    assert_response :success
    assert_template 'templates/default'
    assert_tag :div, :attributes=>{:id=>'documents'}
    assert_tag :ul, :attributes=>{:class=>'list', :id=>"documents_list"}
    assert_tag :li, :attributes=>{:class=>'btn_add', :id=>"add_document"}
  end
  
  def test__pages_cannot_write
    get 'show', :path=>['projects'], :prefix=>prefix
    assert_response :success
    assert_template 'templates/default'
    assert_tag :div, :attributes=>{:id=>'pages'}
    assert_tag :ul, :attributes=>{:class=>'list', :id=>"pages_list"}
    assert_no_tag :li, :attributes=>{:class=>'btn_add', :id=>"add_page"}
  end
  
  def test__documents_cannot_write
    get 'show', :path=>['projects'], :prefix=>prefix
    assert_response :success
    assert_template 'templates/default'
    assert_tag :div, :attributes=>{:id=>'documents'}
    assert_tag :ul, :attributes=>{:class=>'list', :id=>"documents_list"}
    assert_no_tag :li, :attributes=>{:class=>'btn_add', :id=>"add_document"}
  end
  
end
