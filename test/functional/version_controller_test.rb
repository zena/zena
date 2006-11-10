require File.dirname(__FILE__) + '/../test_helper'
require 'version_controller'

# Re-raise errors caught by the controller.
class VersionController; def rescue_action(e) raise e end; end

class VersionControllerTest < ControllerTestCase
  fixtures :versions, :items
  def setup
    @controller = VersionController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end
  
  ## 
  ## def test_view_version
  ##   login(:ant)
  ##   v = versions(:lake_red_en)
  ##   get 'version', :id=>versions_id(:lake_red_en), :prefix=>url_prefix
  ##   assert_response :success
  ##   logout
  ##   get 'version', :id=>versions_id(:lake_red_en), :prefix=>url_prefix
  ##   assert_redirected_to '404'
  ## end
  
  def test_can_edit
    login(:ant)
    post 'edit', :id=>items_id(:status)
    assert_tag 'form'
    post 'edit', :version_id=>versions_id(:lake_red_en)
    assert_tag 'form'
    get 'edit', :id=>items_id(:status)
    assert_tag 'form'
    get 'edit', :version_id=>versions_id(:lake_red_en)
    assert_tag 'form'
  end
  
  #def test_cannot_edit
  #  post 'edit', :id=>items_id(:status)
  #  assert_no_tag
  #  post 'edit', :version_id=>versions_id(:lake_red_en)
  #  assert_no_tag
  #  get 'edit', :id=>items_id(:status)
  #  assert_no_tag
  #  get 'edit', :version_id=>versions_id(:lake_red_en)
  #  assert_no_tag
  #end
  #
  #def test_can_not_publish
  #  login(:ant)
  #  post 'publish', :version_id=>versions_id(:lake_red_en)
  #  assert_redirected_to "/#{AUTHENTICATED_PREFIX}/w/version/27"
  #  assert_equal "Could not publish.", flash[:error]
  #  assert_equal Zena::Status[:red], versions(:lake_red_en).status
  #end
  #
  #def test_can_publish
  #  login(:tiger)
  #  post 'publish', :version_id=>versions_id(:lake_red_en)
  #  assert_redirected_to "/#{AUTHENTICATED_PREFIX}/w/version/27"
  #  assert_equal Zena::Status[:pub], versions(:lake_red_en).status
  #end
  #
  #def test_can_preview
  #  login(:ant)
  #  post 'preview', :item=>{:id=>items_id(:status), :title=>"I am a new title", :text=>"I am new text"}
  #  assert_equal "text/javascript", @response.headers["Content-Type"]
  #  assert_rjs_tag :rjs => {:block => 'title' }, :content=>"I am a new title"
  #  assert_rjs_tag :rjs => {:block => 'content' }, :tag=>'p', :content=>"I am new text"
  #end
  #
  #def test_cannot_preview
  #  post 'preview', :item=>{:id=>items_id(:status), :title=>"I am a new title", :text=>"I am new text"}
  #  assert_no_tag
  #end
  #
  #def test_can_save
  #  login(:ant)
  #  post 'save', :item=>{:id=>items_id(:status), :title=>"I am a new title", :text=>"I am new text"}
  #  assert_response :success
  #  assert_no_tag :tag=>'div', :attributes=>{:id=>'error'}
  #end
  #
  #def test_cannot_save
  #  post 'save', :item=>{:id=>items_id(:status), :title=>"I am a new title", :text=>"I am new text"}
  #  assert_no_tag
  #end
  #
  #def test_can_propose
  #  login(:ant)
  #  post 'save', :item=>{:id=>items_id(:status), :title=>"I am a new title", :text=>"I am new text"}
  #  v = Version.find(:first, :order=>"id DESC").id
  #  post 'propose', :version_id=>v
  #  assert_redirected_to "#{AUTHENTICATED_PREFIX}/w/version/#{v}"
  #end
  #
  #def test_cannot_propose
  #  login(:tiger)
  #  post 'save', :item=>{:id=>items_id(:status), :title=>"I am a new title", :text=>"I am new text"}
  #  v = Version.find(:first, :order=>"id DESC").id
  #  login(:ant)
  #  post 'propose', :version_id=>v
  #  assert_no_tag
  #end
  #
  #def test_can_manage
  #  login(:tiger)
  #  post 'manage', :id=>items_id(:status)
  #  assert_tag :tag=>'div'
  #  get 'manage', :id=>items_id(:status)
  #  assert_tag :tag=>'div'
  #end
  #
  #def test_cannot_manage
  #  login(:ant)
  #  post 'manage', :id=>items_id(:status)
  #  assert_no_tag
  #  get 'manage', :id=>items_id(:status)
  #  assert_no_tag
  #end
end
