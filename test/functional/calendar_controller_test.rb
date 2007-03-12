require File.dirname(__FILE__) + '/../test_helper'
require 'calendar_controller'

# Re-raise errors caught by the controller.
class CalendarController; def rescue_action(e) raise e end; end

class CalendarControllerTest < ZenaTestController

  def setup
    super
    @controller = CalendarController.new
    init_controller
  end

  def test_show_date
    get 'show', :date=>Date.civil(2006,11,1).to_s, :size=>'tiny', :id=>nodes_id(:zena), :find=>'news'
    assert_response :success
    assert_match %r{tinycal.*class='sun'><p>19}m, @response.body
  end

  def test_open_cal
    get 'open', :date=>Date.civil(2006,11,1).to_s, :size=>'large', :id=>nodes_id(:zena), :find=>'news'
    assert_response :success
    assert_match %r{\$\('notes'\).style.display.*none}, @response.body
    assert_match %r{largecal.*class='sun'><p>19}m, @response.body
    assert_match %r{\$\('tinycal'\).style.visibility.*hidden}, @response.body
    assert_match %r{\$\('tinycal_close'\).style.visibility.*visible}, @response.body
    assert_match %r{\$\('largecal'\).style.display.*block}, @response.body
  end
  
  def test_date_selection
  end
end
