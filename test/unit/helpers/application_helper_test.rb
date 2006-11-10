require File.dirname(__FILE__) + '/../../test_helper'

class ApplicationHelperTest < HelperTestCase
  include ApplicationHelper

  def setup
    @controllerClass = ApplicationController
    super
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
  
  def test_check_lang_same
    session[:lang] = 'en'
    obj = Item.find(1)
    assert_equal 'en', obj.v_lang
    assert_no_match /\[en\]/, check_lang(obj)
  end
  
  def test_check_other_lang
    session[:lang] = 'io'
    obj = Item.find(1)
    assert_match /\[en\]/, check_lang(obj)
  end
  
  def test_plug_btn_for_public
    @item = @controller.send(:secure,Item) { Item.find(11) } # 11 cleanWater
    assert !@item.can_edit?, "Item cannot be edited by the public"
    res = plug_btn(:all)
    assert_equal '', res
  end
  
  def test_plug_btn_wiki_public
    @item = @controller.send(:secure,Item) { Item.find(19) } # 19 wiki 
    assert @item.can_edit?, "Item can be edited by the public"
    res = plug_btn(:all)
    assert_match %r{/z/version/edit/19}, res
    assert_match %r{/z/item/drive\?.*version_id=19}, res
  end
  
  def test_item_actions_for_ant
    login(:ant)
    @item = @controller.send(:secure,Item) { Item.find(11) } # 11 cleanWater
    res = plug_btn(:all)
    assert_match %r{/z/version/edit}, res
    assert_no_match %r{/z/item/drive}, res
  end
  
  def test_item_actions_for_tiger
    login(:tiger)
    @item = @controller.send(:secure,Item) { Item.find(11) } # 11 cleanWater
    res = plug_btn(:all)
    assert_match %r{/z/version/edit}, res
    assert_match %r{/z/item/drive}, res
    @item.edit
    res = plug_btn(:all)
    assert_match %r{/z/version/edit}, res
    assert_match %r{/z/version/propose}, res
    assert_match %r{/z/version/publish}, res
    assert_match %r{/z/item/drive}, res
    @item.save
    login(:ant)
    session[:lang] = 'fr'
    @item = @controller.send(:secure,Item) { Item.find(11) } # 11 cleanWater
    res = plug_btn(:all)
    assert_match %r{/z/version/edit}, res
    assert_no_match %r{/z/item/drive}, res
    session[:lang] = 'en'
    @item = @controller.send(:secure,Item) { Item.find(11) } # 11 cleanWater
    res = plug_btn(:all)
    assert_no_match %r{/z/version/edit}, res
    assert_no_match %r{/z/item/drive}, res
  end
  
  def test_plug_logout
    assert_equal "<div id='logout'><a href='/login'>login</a></div>", plug_logout
    login(:ant)
    assert_equal "<div id='logout'><a href='/logout'>logout</a></div>", plug_logout
  end
  
  def test_traductions
    login(:tiger) # session[:lang] = 'en'
    @item = @controller.send(:secure,Item) { Item.find(12) } # 12 status (en,fr)
    trad = traductions
    assert_equal 2, trad.size
    @item = @controller.send(:secure,Item) { Item.find(11) } # 11 cleanWater (en)
    trad = traductions
    assert_equal 1, trad.size
  end
  
  def test_change_lang
    assert false, 'test todo'
  end
  
  def test_trans
    assert_equal 'yoba', trans('yoba')
    assert_equal '%Y-%m-%d', trans('long_date')
    session[:lang] = 'fr'
    assert_equal '%d.%m.%Y', trans('long_date')
    session[:lang] = 'io'
    assert_equal '%Y-%m-%d', trans('long_date')
    session[:translate] = true
    assert_match /div.*translation.*Ajax.*\%Y-\%m-\%d/, trans('long_date')
  end
  
  def test_long_time
    atime = Time.now
    assert_equal atime.strftime('%H:%M:%S'), format_date("long_time", atime)
    session[:lang] = 'fr'
    assert_equal atime.strftime('heure: %H:%M:%S'), format_date("long_time", atime)
  end
  
  def test_short_time
    atime = Time.now
    assert_equal atime.strftime('%H:%M'), format_date("short_time", atime)
    session[:lang] = 'fr'
    assert_equal atime.strftime('%Hh%M'), format_date("short_time", atime)
  end
  
  def test_long_date
    atime = Time.now
    assert_equal atime.strftime('%Y-%m-%d'), format_date("long_date", atime)
    session[:lang] = 'fr'
    assert_equal atime.strftime('%d.%m.%Y'), format_date("long_date", atime)
  end
  
  def test_short_date
    atime = Time.now
    assert_equal atime.strftime('%m.%d'), format_date("short_date", atime)
    session[:lang] = 'fr'
    assert_equal atime.strftime('%d.%m'), format_date("short_date", atime)
  end
  
  def test_format_date
    
    session[:lang] = 'fr'
  end
  
  # Parse date : return a date from a string
  def test_parseDate(str, fmt=trans("long_date"))
  end
end
