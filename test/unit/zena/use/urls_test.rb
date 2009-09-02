require 'test_helper'

class UrlsTest < Zena::View::TestCase
  include Zena::Use::Urls::Common
  
  def test_zen_path
    login(:ant)
    node = secure!(Node) { nodes(:zena) }
    assert_equal "/oo", zen_path(node)
    assert_equal "/oo/project11_test.html", zen_path(node, :mode=>'test')
    
    login(:anon)
    node = secure!(Node) { nodes(:zena) }
    assert_equal "/en", zen_path(node)
    assert_equal "/en/project11_test.html", zen_path(node, :mode=>'test')
    node = secure!(Node) { nodes(:people) }
    assert_equal "/en/section12.html", zen_path(node)
    assert_equal "/en/section12_test.html", zen_path(node, :mode=>'test')
    assert_equal "/tt/section12_test.jpg", zen_path(node, :mode=>'test', :prefix=>'tt', :format=>'jpg')
    node = secure!(Node) { nodes(:cleanWater) }
    assert_equal "/en/projects/cleanWater", zen_path(node)
    assert_equal "/en/projects/cleanWater_test", zen_path(node, :mode=>'test')
    node = secure!(Node) { nodes(:status) }
    assert_equal "/en/projects/cleanWater/page22.html", zen_path(node)
    assert_equal "/en/projects/cleanWater/page22_test.html", zen_path(node, :mode=>'test')
  end
  
  def test_zen_path_asset
    login(:ant)
    node = secure!(Node) { nodes(:zena) }
    assert_equal "/oo/project11.abcd.html", zen_path(node, :asset=>'abcd')
    node = secure!(Node) { nodes(:people) }
    assert_equal "/oo/section12.m1234.png", zen_path(node, :asset=>'m1234', :format=>'png')
    
    login(:anon)
    node = secure!(Node) { nodes(:zena) }
    assert_equal "/en/project11.abcd.png", zen_path(node, :asset=>'abcd', :format=>'png')
    node = secure!(Node) { nodes(:people) }
    assert_equal "/en/section12.kls.html", zen_path(node, :asset=>'kls')
    assert_equal "/tt/section12.foo.jpg", zen_path(node, :mode=>'test', :prefix=>'tt', :format=>'jpg', :asset => 'foo')
    node = secure!(Node) { nodes(:cleanWater) }
    assert_equal "/en/projects/cleanWater.kls", zen_path(node, :asset => 'kls')
    node = secure!(Node) { nodes(:status) }
    assert_equal "/en/projects/cleanWater/page22.abcd.png", zen_path(node, :asset => 'abcd', :format => 'png')
  end
  
  def test_zen_url
    params[:format] = 'html'
    node = secure!(Node) { nodes(:zena) }
    assert_equal "http://test.host/en", zen_url(node)
    assert_equal "http://test.host/en/project11_test.html", zen_url(node, :mode=>'test')
  end
  
  def test_data_path_for_public_documents
    login(:ant)
    node = secure!(Node) { nodes(:water_pdf) }
    assert_equal "/en/projects/cleanWater/document25.pdf", data_path(node)
    node = secure!(Node) { nodes(:status) }
    assert_equal "/oo/projects/cleanWater/page22.html", data_path(node)
    
    login(:anon)
    node = secure!(Node) { nodes(:water_pdf) }
    assert_equal "/en/projects/cleanWater/document25.pdf", data_path(node)
    node = secure!(Node) { nodes(:status) }
    assert_equal "/en/projects/cleanWater/page22.html", data_path(node)
  end
  
  def test_data_path_for_non_public_documents
    login(:tiger)
    node = secure!(Node) { nodes(:water_pdf) }
    assert node.update_attributes( :rgroup_id => groups_id(:workers), :inherit => 0 )
    assert !node.public?
    assert_equal "/oo/projects/cleanWater/document25.pdf", data_path(node)
    node = secure!(Node) { nodes(:status) }
    assert_equal "/oo/projects/cleanWater/page22.html", data_path(node)
    
    login(:anon)
    assert_raise(ActiveRecord::RecordNotFound) { secure!(Node) { nodes(:water_pdf) } }
  end
  
  #### ============================================================ TO MOVE TO OTHER MODULE TESTS
  def test_uses_calendar_with_lang
    res = uses_calendar
    assert_match %r{/calendar/lang/calendar-en-utf8.js}, res
  end
  
  def test_uses_calendar_without_lang
    visitor.lang = 'io'
    res = uses_calendar
    assert_no_match %r{/calendar/lang/calendar-io-utf8.js}, res
    assert_match %r{/calendar/lang/calendar-en-utf8.js}, res
  end
  
  def test_cal_weeks
    login(:tiger)
    weeks = []
    event_hash = nil
    assert_equal "0", _('week_start_day') # week starts on Sunday
    start_date, end_date = cal_start_end(Time.utc(2006,3,18), :month)
    assert_equal Date.civil(2006,02,26), start_date
    assert_equal Date.civil(2006,04,01), end_date
    secure!(Note) { Note.create(:parent_id => nodes_id(:zena), :name => 'foobar', :event_at => Time.utc(2006,03,20))}
    nodes = secure!(Note) { Note.find(:all, :conditions => ["nodes.event_at >= ? AND nodes.event_at <= ?", start_date, end_date])}
    res = cal_weeks('event_at', nodes, start_date, end_date) do |week, hash|
      weeks << week
      event_hash = hash
    end
    assert_equal ["2006-03-18 00", "2006-03-20 00"], event_hash.keys.sort
    assert_equal ['opening'], event_hash["2006-03-18 00"].map{|r| r.name}
    assert_equal ['foobar'], event_hash["2006-03-20 00"].map{|r| r.name}
  end
  
  def test_cal_weeks_hours
    login(:tiger)
    weeks = []
    event_hash = nil
    hours = [0,12]
    assert_equal "0", _('week_start_day') # week starts on Sunday
    start_date, end_date = cal_start_end(Time.utc(2006,3,18), :month)
    assert_equal Date.civil(2006,02,26), start_date
    assert_equal Date.civil(2006,04,01), end_date
    secure!(Note) { Note.create(:parent_id => nodes_id(:zena), :name => 'morning', :event_at => Time.utc(2006,03,20,9))}
    secure!(Note) { Note.create(:parent_id => nodes_id(:zena), :name => 'afternoon', :event_at => Time.utc(2006,03,20,14))}
    nodes = secure!(Note) { Note.find(:all, :conditions => ["nodes.event_at >= ? AND nodes.event_at <= ?", start_date, end_date])}
    res = cal_weeks('event_at', nodes, start_date, end_date, hours) do |week, hash|
      weeks << week
      event_hash = hash
    end
    assert_equal ["2006-03-18 12", "2006-03-20 00", "2006-03-20 12"], event_hash.keys.sort
    assert_equal ['opening'], event_hash["2006-03-18 12"].map{|r| r.name}
    assert_equal ['morning'], event_hash["2006-03-20 00"].map{|r| r.name}
    assert_equal ['afternoon'], event_hash["2006-03-20 12"].map{|r| r.name}
  end
  
  def test_javascript
    assert_nothing_raised { javascript('test') }
  end
  
  def test_rnd
    assert ((Time.now.to_i-1 <= rnd) && (rnd <= Time.now.to_i+2))
  end
  
  def test_login_link
    assert_equal "<a href='/login'>login</a>", login_link
    login(:ant)
    assert_equal "<a href='/logout'>logout</a>", login_link
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
  
  def test_check_lang_same
    I18n.locale = 'en'
    obj = secure!(Node) { nodes(:zena) }
    assert_equal 'en', obj.v_lang
    assert_no_match /\[en\]/, check_lang(obj)
  end
  
  def test_check_other_lang
    visitor.lang = 'es'
    I18n.locale = 'es'
    obj = secure!(Node) { nodes(:zena) }
    assert_match /\[en\]/, check_lang(obj)
  end
  
  def test_change_lang
    assert_equal ({:overwrite_params=>{:prefix=>'io'}}), change_lang('io')
    login(:ant)
    assert_equal ({:overwrite_params=>{:lang=>'io'}}), change_lang('io')
  end
  
  def test_traductions
    session[:lang] = 'en'
    # we must initialize an url for url_rewriting in 'traductions'
    @controller.instance_eval { @url = ActionController::UrlRewriter.new( @request, {:controller=>'nodes', :action=>'index'} ) }
    @node = secure!(Node) { Node.find(nodes_id(:status)) } # en,fr
    trad = traductions
    assert_equal 2, trad.size
    assert_match %r{class='current'.*href="/en}, trad[0]
    assert_no_match %r{class='current'}, trad[1]
    @node = secure!(Node) { Node.find(nodes_id(:cleanWater)) } #  en
    trad = traductions
    assert_equal 1, trad.size
  end
  
  def test_show_path_root
    @node = secure!(Node) { Node.find(nodes_id(:zena))}
    assert_equal "<li><a href='/en' class='current'>zena</a></li>", show_path
    @node = secure!(Node) { Node.find(nodes_id(:status))}
    assert_match %r{.*zena.*projects.*cleanWater.*li.*page22\.html' class='current'>status}m, show_path
  end
  
  def test_show_path_root_with_login
    login(:ant)
    @node = secure!(Node) { Node.find(nodes_id(:zena))}
    assert_equal "<li><a href='/#{AUTHENTICATED_PREFIX}' class='current'>zena</a></li>", show_path
  end

  def test_lang_links
    login(:lion)
    @controller.set_params(:controller=>'nodes', :action=>'show', :path=>'projects/cleanWater', :prefix=>AUTHENTICATED_PREFIX)
    assert_match %r{<em>en</em>.*href=.*/oo/projects/cleanWater\?lang=.*fr.*}, lang_links
  end
  
  def test_lang_links_no_login
    login(:anon)
    @controller.set_params(:controller=>'nodes', :action=>'show', :path=>'projects/cleanWater', :prefix=>'en')
    assert_match %r{<em>en</em>.*href=.*/fr/projects/cleanWater.*fr.*}, lang_links
  end
  
  def test_timezones
    login(:ant)
    visitor[:time_zone] = "Europe/Zurich"
    
    # UTC+1, no Daylight time savings
    assert_equal Time.utc(2008,1,3,12,03,10), "2008-01-03 13:03:10".to_utc('%Y-%m-%d %H:%M:%S', visitor.tz)
    # UTC+1, Daylight time savings
    assert_equal Time.utc(2008,5,17,11,03,10), "2008-05-17 13:03:10".to_utc('%Y-%m-%d %H:%M:%S', visitor.tz)
    
    # convert back and forth
    [
      ["2008-05-17 13:03:10", '%Y-%m-%d %H:%M:%S'],
      ["03.01.2008 13:03:10", '%d.%m.%Y %H:%M:%S'],
    ].each do |date_str, format|
      assert_equal date_str, format_date(date_str.to_utc(format, visitor.tz), format)
    end
    
    login(:ant) # Europe/Paris
    visitor[:time_zone] = "Asia/Jakarta"
    
    # UTC+7, no Daylight time savings
    assert_equal Time.utc(2008,1,3,12,03,10), "2008-01-03 19:03:10".to_utc('%Y-%m-%d %H:%M:%S', visitor.tz)
    # UTC+7, no Daylight time savings
    assert_equal Time.utc(2008,5,17,12,03,10), "2008-05-17 19:03:10".to_utc('%Y-%m-%d %H:%M:%S', visitor.tz)
    
    
    # convert back and forth
    [
      ["2008-05-17 13:03:10", '%Y-%m-%d %H:%M:%S'],
      ["03.01.2008 13:03:10", '%d.%m.%Y %H:%M:%S'],
    ].each do |date_str, format|
      assert_equal date_str, format_date(date_str.to_utc(format, visitor.tz), format)
    end
  end
  
  
end
