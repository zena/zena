require 'test_helper'

class SitesControllerTest < Zena::Controller::TestCase

  def setup
    login(:lion)
  end

  test 'should clear cache' do
    with_caching do
      login(:anon)
      @node = secure!(Node) { nodes(:status) }
      filepath = "#{RAILS_ROOT}/sites/test.host/public/en/clear_cache_test.html"
      assert !File.exist?(filepath)
      secure!(CachedPage) { CachedPage.create(:expire_after => nil, :path => "/test.host/public/en/clear_cache_test.html", :content_data => "houbahouba", :node_id => @node[:id], :expire_with_ids => visitor.visited_node_ids) }
      assert File.exist?(filepath)
      assert CachedPage.find(:first, :conditions => ["path = ?", "/test.host/public/en/clear_cache_test.html"])
      login(:lion)
      post 'clear_cache', :id => visitor.site.id
      assert !File.exist?(filepath)
      assert !CachedPage.find(:first, :conditions => ["path = ?", "/test.host/public/en/clear_cache_test.html"])
    end
  end

  test 'clearing cache should clear zafu' do
    with_caching do
      login(:anon)
      @node = secure!(Node) { nodes(:status) }
      filepath = "#{RAILS_ROOT}/sites/test.host/zafu/default/Node/fr/_main.erb"
      FileUtils.mkpath(File.dirname(filepath))
      File.open(filepath, 'wb') {|f| f.puts "puts 'hello'"}
      assert File.exist?(filepath)
      login(:lion)
      post 'clear_cache', :id => visitor.site.id
      assert !File.exist?(filepath)
    end
  end


  test "should not have access to sites if not admin" do
    login(:tiger)
    get :index
    assert_response :missing
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:sites)
  end

  test "should not get new" do
    get :new
    assert_response :missing
  end

  test "should create not be able to create site" do
    assert_difference('Site.count', 0) do
      post :create, :site => { :host => 'foo.host', :pass => 'secret' }
    end
    assert_response :missing
    assert_nil assigns(:site)
  end

  test "should show site" do
    get :show, :id => sites_id(:zena)
    assert_response :success
  end

  test "should not show other site" do
    get :show, :id => sites_id(:ocean)
    assert_response :missing
  end

  test "should get edit" do
    get :edit, :id => sites_id(:zena)
    assert_response :success
  end

  test "should not get edit other site" do
    get :edit, :id => sites_id(:ocean)
    assert_response :missing
  end

  test "should update site" do
    put :update, :id => sites_id(:zena), :site => { :languages => 'it,es', :default_lang => 'es'}
    site = assigns(:site)
    assert_redirected_to site_path(site)
    assert_equal 'it,es', site.languages
  end

  test "should not update other site" do
    put :update, :id => sites_id(:ocean), :site => { :languages => 'it,es'}
    assert_response :missing
  end

  test "should not destroy site" do
    assert_difference('Site.count', 0) do
      delete :destroy, :id => sites_id(:zena)
    end
    assert_response :missing
  end
end