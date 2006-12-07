require File.dirname(__FILE__) + '/../test_helper'
require 'calendar_controller'

# Re-raise errors caught by the controller.
class CalendarController; def rescue_action(e) raise e end; end

class CalendarControllerTest < Test::Unit::TestCase
  include ZenaTestController

  def setup
    @controller = CalendarController.new
    init_controller
  end

  def test_show_date
    get 'show', :date=>Date.civil(2006,11,1).to_s, :size=>'tiny', :id=>items_id(:zena), :find=>'news'
    assert_response :success
    assert_match %r{tiod}, @response.body
  end

  def test_open_cal
    get 'open', :date=>Date.civil(2006,11,1).to_s, :size=>'large', :id=>items_id(:zena), :find=>'news'
    assert_response :success
    assert_rjs_tag :rjs => {:block=>'largecal'}, :tag=>:table, :attributes=>{:class=>'largecal'}, :child=>{:tag=>'p', :content=>'1'}
    assert_rjs_tag :rjs => {:block=>'largecal'}, :tag=>:td, :attributes=>{:class=>'sunother'},    :child=>{:tag=>'p', :content=>'3'}
    assert_rjs_tag :rjs => {:block=>'largecal'}, :tag=>:td, :attributes=>{:class=>'sat'}, :content=>'4'
  end

  def test_today_format
    get 'show', :date=>Date.today.to_s, :size=>'tiny', :id=>items_id(:zena)
    assert_response :success
    assert_tag :td, :attributes=>{:id=>'tiny_today'},  :child=>{:tag=>'p', :content=>Date.today.day.to_s}
    get 'show', :date=>Date.today.to_s, :size=>'large', :id=>items_id(:zena)
    assert_response :success
    assert_tag :td, :attributes=>{:id=>'large_today'}, :child=>{:tag=>'p', :content=>Date.today.day.to_s}
  end
end
