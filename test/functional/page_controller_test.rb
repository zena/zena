require File.dirname(__FILE__) + '/../test_helper'
require 'page_controller'

# Re-raise errors caught by the controller.
class PageController; def rescue_action(e) raise e end; end

class PageControllerTest < ZenaTestController

  def setup
    @controller = PageController.new
    init_controller
  end
  
  def test_create_without_rights
    post 'create', :page=>{:vclass=>'Page', :parent_id=>1, :name=>'test'}
    assert_response :success
    assert assigns['page'].new_record?
    assert_equal 'invalid reference', assigns['page'].errors[:parent_id]
  end
  
  def test_create_bad_klass
    login(:tiger)
    post 'create', :page=>{:vclass=>'system "pwd"', :parent_id=>1, :name=>'test'}
    assert_response :success
    assert_equal 'invalid', assigns['page'].errors[:vclass]
    assert_equal 'system "pwd"', assigns['page'].klass
    
    post 'create', :page=>{:vclass=>'Node', :parent_id=>1, :name=>'test'}
    assert_response :success
    assert_equal 'invalid', assigns['page'].errors[:vclass]
    assert_equal 'Node', assigns['page'].klass
  end
  
end
