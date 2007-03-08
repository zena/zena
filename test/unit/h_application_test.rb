require File.dirname(__FILE__) + '/../test_helper'

class ApplicationHelperTest < Test::Unit::TestCase

  include ZenaTestHelper
  include ApplicationHelper

  def setup
    @controllerClass = ApplicationController
    super
  end
  
  def test_nodes_id
    assert_equal nodes(:zena)[:id], nodes_id(:zena)
  end
  
  def test_acts_as_secure
    login(:ant)
    assert_nothing_raised { @node = secure(Node) { Node.find(nodes_id(:myLife))} }
    assert_equal 'myLife', @node.name
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
  
  def test_link_box
    @node = secure(Node) { nodes(:letter) }
    assert_equal "<ul class='link_box'><li><b>calendars</b></li><li><input type='checkbox' name='node[calendar_ids][]' value='19' class='box' />wiki</li></ul>", link_box('node', :calendars)
    login(:tiger)
    @node = secure(Node) { nodes(:letter) }
    assert_match %r{ul class='link_box'.*node\[calendar_ids\]\[\].*1.*9.*11.*19}, link_box('node', :calendars)
    assert_match %r{node\[hot_for_ids\]\[\].*11.*19}, link_box('node', :hot_for, :in=>[11,19,13])
    assert_no_match %r{13}, link_box('node', :hot_for, :in=>[11,19,13])
    @node = secure(Node) { nodes(:cleanWater) }
    assert_match %r{node\[hot_id\].*12}, link_box('node', :hot)
  end 
  
  def test_select_id
    @node = secure(Node) { nodes(:status) }
    select = select_id('node', :parent_id, :class=>'Project')
    assert_no_match %r{select.*node\[parent_id\].*11.*9.*19.*1}m, select
    assert_match %r{select.*node\[parent_id\].*19}, select
    login(:tiger)
    @node = secure(Node) { nodes(:status) }
    assert_match %r{select.*node\[parent_id\].*11.*9.*19.*1}m, select_id('node', :parent_id, :class=>'Project')
    assert_match %r{input type='text'.*node\[icon_id\].*node_icon_id_name}m, select_id('node', :icon_id)
  end
  
  def test_date_box
    assert false, 'todo'
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
  
  def test_rnd
    assert ((Time.now.to_i-1 <= rnd) && (rnd <= Time.now.to_i+2))
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
    assert_match /div.*trans_75.*Ajax.*\%A, \%B \%d \%Y/, trans('full_date')
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
  
  def test_parse_date_time
    assert_equal Time.gm(2006,11,10,12,30), parse_date('2006-11-10 12:30', '%Y-%m-%d %H:%M')
    assert_equal Time.gm(2006,11,10,12,30), parse_date('2006-11-10 12:30')
    assert_equal Time.gm(2006,11,10,12,30), parse_date('10.11.2006 12:30', '%d.%m.%Y %H:%M')
  end
  
  def login_link
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
  
  def test_data_url
    obj = secure(Node) { nodes(:water_pdf) }
    hash = {:controller=>'document', :action=>'data', :version_id=>obj.v_id, :filename=>obj.c_filename, :ext=>obj.c_ext}
    assert_equal hash, data_url(obj)
    obj = secure(Node) { nodes(:projects) }
    assert_raise(StandardError) { data_url(obj) }
  end
  
  def test_fsize
    assert_equal '29 Kb', fsize(29279)
    assert_equal '502 Kb', fsize(513877)
    assert_equal '5.2 Mb', fsize(5480809)
    assert_equal '450.1 Mb', fsize(471990272)
    assert_equal '2.35 Gb', fsize(2518908928)
  end
  # zazen is tested in zazen_test.rb
  
  def test_render_to_string
    assert_match 'stupid test 25', render_to_string(:inline=>'stupid <%= "test" %> <%= 5*5 %>')
  end
  
  def test_menu
    menus = nil
    assert_nothing_raised { menus = show_menu }
    assert_no_match %r{bananas}, menus
    login(:tiger)
    assert_match %r{bananas}, show_menu
  end
  
  def test_calendar_has_note
    op_at = nodes(:opening).log_at
    zena = secure(Node) { nodes(:zena) }
    cal = calendar(:from=>zena, :find=>:news, :date=>Date.civil(op_at.year, op_at.month, 5), :size=>:tiny)
    assert_match %r{class='sun'><p>12}, cal
    assert_match %r{<b class='has_note'>15}, cal
    cal = calendar(:from=>zena, :find=>:news, :date=>Date.civil(op_at.year, op_at.month, 5), :size=>:large)
    assert_match %r{<p>15.*onclick=.*Updater.*largecal_preview.*/z/calendar/list/.*(selected=17.*|2006-03-15.*)(selected=17.*|2006-03-15.*)</div></p>}m, cal
  end
  
  def test_calendar_today
    zena = secure(Node) { nodes(:zena) }
    cal = calendar(:from=>zena, :find=>:news, :size=>:large)
    assert_match %r{<td[^>*]id='large_today'><p>#{Date.today.day}</p></td>}, cal
    cal = calendar(:from=>zena, :find=>:news, :size=>:tiny)
    assert_match %r{<td[^>*]id='tiny_today'><p>#{Date.today.day}</p></td>}, cal
  end
  
  def test_notes_list_tiny_calendar_list
    login(:tiger)
    proj = secure(Node) { nodes(:cleanWater) }
    note = secure(Note) { Note.create(:parent_id=>nodes_id(:cleanWater), :v_title=>'hello')}
    list = notes(:from=>proj, :find=>:news)
    assert_equal 1, list.size
    assert_equal 'opening', list[0].name
  end
  
  def test_notes_list_from_project
    login(:tiger)
    proj = secure(Node) { nodes(:cleanWater) }
    note = secure(Note) { Note.create(:parent_id=>nodes_id(:cleanWater), :v_title=>'hello')}
    list = notes(:from=>proj, :find=>:notes)
    assert_equal 2, list.size
    assert_equal 'opening', list[0].name
    assert_equal 'hello', list[1].name
  end
end
