require File.dirname(__FILE__) + '/../test_helper'
require 'link_controller'

# Re-raise errors caught by the controller.
class LinkController; def rescue_action(e) raise e end; end

class LinkControllerTest < Test::Unit::TestCase
  include ZenaTestController
  def setup
    @controller = LinkController.new
    init_controller
  end
  
  def test_create_no_rights
    post 'create', :link=>{:node_id=>1, :role=>'tags', :other_id=>nodes_id(:art) }
    assert_response :success
    assert_match %r{link_errors.*not found}, @response.body
  end
  
  def test_create_bad_link
    login(:tiger)
    post 'create', :link=>{:node_id=>1, :role=>'tags', :other_id=>nodes_id(:status) }
    assert_response :success
    assert_match %r{link_errors.*tag.*invalid}, @response.body
  end
  
  def test_create_ok
    login(:tiger)
    post 'create', :link=>{:node_id=>1, :role=>'tags', :other_id=>nodes_id(:art) }
    assert_response :success
    assert_match %r{After.*group_tags.*art}m, @response.body
  end
  
  def test_create_with_name_ok
    login(:tiger)
    post 'create', :link=>{:node_id=>1, :role=>'tags', :other_id=>'art' }
    assert_response :success
    assert_match %r{After.*group_tags.*art}m, @response.body
  end
  
  def test_remove_no_rights
    post 'remove', :node_id=>nodes_id(:cleanWater), :id=>links_id(:cleanWater_in_art)
    assert_response :success
    assert_match %r{link_errors.*node not found}, @response.body
  end
  
  def test_remove_no_rights_on_link
    login(:lion)
    Node.connection.execute "UPDATE nodes SET rgroup_id=NULL, wgroup_id=NULL, pgroup_id=NULL WHERE id='#{nodes_id(:art)}'"
    post 'remove', :node_id=>nodes_id(:cleanWater), :id=>links_id(:cleanWater_in_art)
    assert_response :success
    assert_match %r{link_errors.*tag.*bad link id}, @response.body
  end
  
  def test_remove_ok
    login(:tiger)
    link_id = links_id(:cleanWater_in_art)
    post 'remove', :node_id=>nodes_id(:cleanWater), :id=>link_id
    assert_response :success
    assert_match %r{Highlight.*link#{link_id}.*Fade.*link#{link_id}}m, @response.body
  end
end
