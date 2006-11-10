require File.dirname(__FILE__) + '/../../test_helper'

class ApplicationHelperTest < HelperTestCase
  include ApplicationHelper

  def setup
    @controllerClass = ApplicationController
    super
  end
  def test_items_id
    assert_equal 1, items_id(:zena)
  end
  def test_uses_calendar_with_lang
    res = uses_calendar
    assert_match %r{/calendar/lang/calendar-en-utf8.js}, res
  end
  
  def test_uses_calendar_without_lang
    session[:lang] = 'io'
    res = uses_calendar
    assert_no_match %r{/calendar/lang/calendar-io-utf8.js}, res
    assert_match %r{/calendar/lang/calendar-en-utf8.js}, res
  end
  
  def test_javascript
    assert_nothing_raised { javascript('test') }
  end
  
  def test_tsubmit_tag
    session[:lang] = 'fr'
    assert_equal '<input name="commit" type="submit" value="lundi" />', tsubmit_tag('Monday')
  end
  
  def test_tlink_to_remote
    session[:lang] = 'fr'
    assert_equal "<a href=\"#\" onclick=\"new Ajax.Request('', {asynchronous:true, evalScripts:true}); return false;\">lundi</a>", tlink_to_remote('Monday', :controller=>'version', :action=>'edit')
  end
  
  def test_tlink_to
    session[:lang] = 'fr'
    assert_equal "<a href=\"/z/version/edit\">lundi</a>", tlink_to('Monday', :controller=>'version', :action=>'edit')
  end
  
  def test_tlink_to_function
    session[:lang] = 'fr'
    assert_equal "<a href=\"new Element.hide('drive')\">lundi</a>", tlink_to('Monday', "new Element.hide('drive')")
  end
  
  def test_transb
    session[:translate] = true
    assert_equal trans('Monday',false), transb('Monday')
    assert_not_equal 'lundi', trans('Monday')
  end
  
  def test_salt_against_caching
    assert_equal self.object_id, salt_against_caching
  end
  
  def test_login_link
    assert_equal "<div id='logout'><a href='/login'>login</a></div>", login_link
    login(:ant)
    assert_equal "<div id='logout'><a href='/logout'>logout</a></div>", login_link
  end
  
  def test_trans
    assert_equal 'yoba', trans('yoba')
    assert_equal '%A, %B %d %Y', trans('full_date')
    session[:lang] = 'fr'
    assert_equal '%A, %d %B %Y', trans('full_date')
    session[:lang] = 'io'
    assert_equal '%A, %B %d %Y', trans('full_date')
    session[:translate] = true
    assert_match /div.*translation.*Ajax.*\%A, \%B \%d \%Y/, trans('full_date')
  end
  
  def test_long_time
    atime = Time.gm(2006,11,10,17,42,25)
    assert_equal "17:42:25", long_time(atime)
    session[:lang] = 'fr'
    assert_equal "17:42:25 ", long_time(atime)
  end
  
  def test_short_time
    atime = Time.gm(2006,11,10,17,33)
    assert_equal "17:33", short_time(atime)
    session[:lang] = 'fr'
    assert_equal "17h33", short_time(atime)
  end

  def test_long_date
    atime = Time.gm(2006,11,10)
    assert_equal "2006-11-10", long_date(atime)
    session[:lang] = 'fr'
    assert_equal "10.11.2006", long_date(atime)
  end

  def test_full_date
    atime = Time.gm(2006,11,10)
    assert_equal "Friday, November 10 2006", full_date(atime)
    session[:lang] = 'fr'
    assert_equal "vendredi, 10 novembre 2006", full_date(atime)
  end
  
  def test_short_date
    atime = Time.now
    assert_equal atime.strftime('%m.%d'), short_date(atime)
    session[:lang] = 'fr'
    assert_equal atime.strftime('%d.%m'), short_date(atime)
  end
  
  def test_format_date
    atime = Time.now
    assert_equal atime.strftime('%m.%d'), format_date(atime, 'short_date')
    session[:lang] = 'fr'
    assert_equal atime.strftime('%d.%m'), format_date(atime, 'short_date')
  end
  
  def test_parse_date
    assert_equal Time.gm(2006,11,10), parse_date('2006-11-10', '%Y-%m-%d')
    assert_equal Time.gm(2006,11,10), parse_date('10.11 2006', '%d.%m %Y')
    assert_equal Time.gm(2006,11,10), parse_date('10.11 / 06', '%d.%m.%y')
    assert_equal Time.gm(Time.now.year,11,10), parse_date('11-10', '%m.%d')
  end
  
  def test_visitor_link
    assert_equal '', visitor_link
    login(:ant)
    assert_match /div id='visitor'.*home.*Solenopsis Invicta/, visitor_link
  end
  
  def test_flash_messages
    login(:ant)
    assert_equal '', flash_messages(:both)
    flash[:notice] = 'yoba'
    assert_match /notice.*yoba/, flash_messages(:both)
    assert_no_match /error/, flash_messages(:both)
    flash[:error] = 'taio'
    assert_match /notice.*yoba/, flash_messages(:both)
    assert_match /error.*taio/, flash_messages(:both)
    flash[:notice] = nil
    assert_no_match /notice/, flash_messages(:both)
    assert_match /error/, flash_messages(:both)
  end
  
  def test_logo
    assert_match /logo.*img\/logo.png.*logo_msg/, logo
    assert_match /logo.*img\/logo.png.*logo_msg.*yoba/, logo('yoba')
    assert_match /logo.*img\/logo.png.*logo_msg.*Friday.*November/, logo(Time.gm(2006,11,10))
    session[:lang] = 'fr'
    assert_match /logo.*img\/logo.png.*logo_msg.*vendredi.*novembre/, logo(Time.gm(2006,11,10))
  end
end
