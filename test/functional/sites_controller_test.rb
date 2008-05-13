require File.dirname(__FILE__) + '/../test_helper'
require 'sites_controller'

# Re-raise errors caught by the controller.
class SitesController; def rescue_action(e) raise e end; end

class SitesControllerTest < ZenaTestController
  
  def setup
    super
    @controller = SitesController.new
    init_controller
  end
  
  def test_clear_cache
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
  
  def test_clear_cache_clears_zafu
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
end