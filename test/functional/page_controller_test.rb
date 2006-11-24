require File.dirname(__FILE__) + '/../test_helper'
require 'page_controller'

# Re-raise errors caught by the controller.
class PageController; def rescue_action(e) raise e end; end

class PageControllerTest < Test::Unit::TestCase
  include ZenaTestController

  def setup
    @controller = PageController.new
    init_controller
  end
  
  def test_create_without_rights
    post 'create', :page=>{:type=>'Page', :parent_id=>1, :name=>'test'}
    assert_redirected_to '404'
  end
  
  def test_create
    login(:tiger)
    post 'create', :page=>{:type=>'Page', :parent_id=>1, :name=>'test'}
    assert_response :success
  end
end
