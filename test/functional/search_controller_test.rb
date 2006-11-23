require File.dirname(__FILE__) + '/../test_helper'
require 'search_controller'

# Re-raise errors caught by the controller.
class SearchController; def rescue_action(e) raise e end; end

class SearchControllerTest < Test::Unit::TestCase
  include ZenaTestController

  def setup
    @controller = SearchController.new
    init_controller
  end
  
  def test_find_in_edit
    post 'find_in_edit', :id=>items_id(:people)
    assert_response :success
    assert_equal 2, assigns['results'].size
    
    login(:ant)
    post 'find_in_edit', :id=>items_id(:people)
    assert_response :success
    assert_equal 3, assigns['results'].size
    
    post 'find_in_edit', :search=>'lake'
    assert_response :success
    assert_equal 2, assigns['results'].size
    assert_tag :td, :attributes=>{:class=>'result_image'}
    
    post 'find_in_edit', :search=>'ant'
    assert_response :success
    assert_equal 1, assigns['results'].size
    assert_equal 'ant', assigns['results'][0].name
    assert_no_tag :td, :attributes=>{:class=>'result_image'}
    
    logout
    post 'find_in_edit', :search=>'ant'
    assert_response :success
    assert_equal [], assigns['results']
  end
end
