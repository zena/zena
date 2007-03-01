require File.dirname(__FILE__) + '/../test_helper'
require 'version_controller'

# Re-raise errors caught by the controller.
class VersionController
  def rescue_action(e); raise e; end
end

class HelperVersionController < VersionController
  include VersionHelper
end

class VersionControllerTest < Test::Unit::TestCase
  include ZenaTestController

  def setup
    super
    @controller = VersionController.new
    init_controller
  end
  
  def test_show
    v = versions(:lake_red_en)
    get 'show', :id=>versions_id(:lake_red_en)
    assert_redirected_to '404'
    login(:ant)
    get 'show', :id=>versions_id(:lake_red_en)
    assert_response :success
    assert_template 'templates/default'
  end
  
  def test_can_edit
    login(:ant)
    post 'edit', :id=>nodes_id(:status)
    assert_tag 'form'
    post 'edit', :version_id=>versions_id(:lake_red_en)
    assert_tag 'form'
    get 'edit', :id=>nodes_id(:status)
    assert_tag 'form'
    get 'edit', :version_id=>versions_id(:lake_red_en)
    assert_tag 'form'
  end
  
  def test_edit_template
    login(:lion)
    post 'edit', :id=>nodes_id(:status)
    assert_response :success
    assert_template 'templates/forms/default'
    post 'edit', :id=>nodes_id(:lion)
    assert_response :success
    assert_template 'templates/forms/any_contact'
  end
  
  def test_cannot_edit
    post 'edit', :id=>nodes_id(:status)                            
    assert_redirected_to :controller=>'main', :action=>'not_found'
    post 'edit', :version_id=>versions_id(:lake_red_en)           
    assert_redirected_to :controller=>'main', :action=>'not_found'
    get 'edit', :id=>nodes_id(:status)                            
    assert_redirected_to :controller=>'main', :action=>'not_found'
    get 'edit', :version_id=>versions_id(:lake_red_en)            
    assert_redirected_to :controller=>'main', :action=>'not_found'
  end
  
  def test_preview
    login(:tiger)
    post 'preview', :node=>{ :id=>nodes_id(:status), :v_title=>'my super goofy new title' }
    assert_rjs_tag :rjs => {:block => 'title' }, :content=>"my super goofy new title"
  end
  
  def test_can_save
    login(:ant)
    post 'save', :node=>{:id=>nodes_id(:status), :v_title=>"I am a new title", :v_text=>"I am new text"}
    assert_response :success
    assert_no_tag :tag=>'div', :attributes=>{:id=>'error'}
    node = secure(Node) { nodes(:status) }
    assert_equal 'I am a new title', node.v_title
  end
  
  def test_cannot_save
    post 'save', :node=>{:id=>nodes_id(:status), :v_title=>"I am a new title", :v_text=>"I am new text"}
    assert_redirected_to '404'
    assert_equal 'status title', secure(Node) { nodes(:status) }.v_title
  end
  
  def test_can_propose
    login(:ant)
    post 'save', :node=>{:id=>nodes_id(:status), :v_title=>"I am a new title", :v_text=>"I am new text"}
    node = secure(Node) { nodes(:status) }
    assert_equal Zena::Status[:red], node.v_status
    post 'propose', :id=>node.v_id
    assert_redirected_to "/z/version/show/#{node.v_id}"
    assert_equal Zena::Status[:prop], secure(Node) { Node.version(node.v_id) }.v_status
  end
  
  def test_cannot_propose
    login(:ant)
    post 'save', :node=>{:id=>nodes_id(:status), :v_title=>"I am a new title", :v_text=>"I am new text"}
    node = secure(Node) { nodes(:status) }
    assert_equal Zena::Status[:red], node.v_status
    login(:tiger)
    post 'propose', :id=>node.v_id
    assert_redirected_to '404'
    assert_equal Zena::Status[:red], secure(Node) { Node.version(node.v_id) }.v_status
  end
  
  def test_can_refuse
    login(:ant)
    post 'save', :node=>{:id=>nodes_id(:status), :v_title=>"I am a new title", :v_text=>"I am new text"}
    node = secure(Node) { nodes(:status) }
    post 'propose', :id=>node.v_id
    login(:tiger)
    post 'refuse', :id=>node.v_id
    assert_redirected_to "/z/version/show/#{node.v_id}"
    assert_equal Zena::Status[:red], Version.find(node.v_id).status
  end
  
  def test_cannot_refuse
    login(:tiger)
    post 'save', :node=>{:id=>nodes_id(:status), :v_title=>"I am a new title", :v_text=>"I am new text"}
    node = secure(Node) { nodes(:status) }
    post 'propose', :id=>node.v_id
    login(:ant)
    post 'refuse', :id=>node.v_id
    assert_redirected_to '404'
    assert_equal Zena::Status[:prop], Version.find(node.v_id).status
  end
  
  
  def test_can_publish
    login(:ant)
    post 'save', :node=>{:id=>nodes_id(:status), :v_title=>"I am a new title", :v_text=>"I am new text"}
    node = secure(Node) { nodes(:status) }
    post 'propose', :id=>node.v_id
    login(:tiger)
    post 'publish', :id=>node.v_id
    assert_redirected_to "/z/version/show/#{node.v_id}"
    assert_equal Zena::Status[:pub], Version.find(node.v_id).status
  end
  
  def test_cannot_publish
    login(:tiger)
    post 'save', :node=>{:id=>nodes_id(:status), :v_title=>"I am a new title", :v_text=>"I am new text"}
    node = secure(Node) { nodes(:status) }
    post 'propose', :id=>node.v_id
    login(:ant)
    post 'publish', :id=>node.v_id
    assert_redirected_to '404'
    assert_equal Zena::Status[:prop], Version.find(node.v_id).status
  end
  
  def test_can_remove
    login(:tiger)
    post 'save', :node=>{:id=>nodes_id(:status), :v_title=>"I am a new title", :v_text=>"I am new text"}
    node = secure(Node) { nodes(:status) }
    post 'publish', :id=>node.v_id
    assert_equal Zena::Status[:pub], Version.find(node.v_id).status
    post 'remove', :id=>node.v_id
    assert_redirected_to "/z/version/show/#{node.v_id}"
    assert_equal Zena::Status[:rem], Version.find(node.v_id).status
  end
  
  def test_cannot_remove
    login(:tiger)
    post 'save', :node=>{:id=>nodes_id(:status), :v_title=>"I am a new title", :v_text=>"I am new text"}
    node = secure(Node) { nodes(:status) }
    post 'publish', :id=>node.v_id
    assert_equal Zena::Status[:pub], Version.find(node.v_id).status
    login(:ant)
    post 'remove', :id=>node.v_id
    assert_redirected_to '404'
    assert_equal Zena::Status[:pub], Version.find(node.v_id).status
  end
  
  def test_form_tabs
    @controller = HelperVersionController.new
    init_controller
    page     = @controller.send(:secure, Node) { Node.find(nodes_id(:status))    }
    contact  = @controller.send(:secure, Node) { Node.find(nodes_id(:lake)) }
    @controller.instance_variable_set(:@node, page)
    assert_equal [["text", "text"], ["title", "title"], ["help", "help"]], @controller.send(:form_tabs)
    @controller.instance_variable_set(:@node, contact)
    assert_equal [["text", "text"], ["title", "title"], ["contact", "any_contact"], ["help", "help"]], @controller.send(:form_tabs)
  end
  # def test_can_redit
  #   login(:tiger)
  #   post 'save', :node=>{:id=>nodes_id(:status), :v_title=>"I am a new title", :v_text=>"I am new text"}
  #   node = secure(Node) { nodes(:status) }
  #   post 'publish', :id=>node.v_id
  #   assert_equal Zena::Status[:pub], Version.find(node.v_id).status
  #   post 'redit', :id=>node.v_id
  #   assert_redirected_to "/z/version/show/#{node.v_id}"
  #   assert_equal Zena::Status[:red], Version.find(node.v_id).status
  # end
  # 
  # def test_cannot_redit
  #   login(:tiger)
  #   post 'save', :node=>{:id=>nodes_id(:status), :v_title=>"I am a new title", :v_text=>"I am new text"}
  #   node = secure(Node) { nodes(:status) }
  #   post 'publish', :id=>node.v_id
  #   assert_equal Zena::Status[:pub], Version.find(node.v_id).status
  #   login(:ant)
  #   post 'redit', :id=>node.v_id
  #   assert_redirected_to '404'
  #   assert_equal Zena::Status[:pub], Version.find(node.v_id).status
  # end
  
end
