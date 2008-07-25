require File.dirname(__FILE__) + '/../test_helper'

class ApplicationHelperTest < ZenaTestHelper
  include ApplicationHelper
  include ActionView::Helpers::TextHelper

  def setup
    @controllerClass = ApplicationController
    super
    login(:anon)
  end
  
  # We have to define section this way in order to share with the StubController. I do not understand why we need to do this, but
  # it works. If anyone has a better idea...
  def session
    @response.session
  end
  
  def test_nodes_id
    assert_equal nodes(:zena)[:id], nodes_id(:zena)
  end
  
  def test_zen_path
    
    login(:ant)
    params[:format] = 'html'
    node = secure!(Node) { nodes(:zena) }
    assert_equal "/oo", zen_path(node)
    assert_equal "/oo/project11_test.html", zen_path(node, :mode=>'test')
    
    login(:anon)
    params[:format] = 'html'
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
  
  def test_img_tag
    login(:ant)
    img = secure!(Node) { nodes(:bird_jpg) }
    assert_equal "<img src='/en/image30.jpg' width='660' height='600' alt='bird' class='full'/>", img_tag(img)
    assert_equal "<img src='/en/image30_pv.jpg' width='70' height='70' alt='bird' class='pv'/>", img_tag(img, :mode=>'pv')
  end
  
  def test_img_tag_document
    login(:ant)
    doc = secure!(Node) { nodes(:water_pdf) }
    assert_equal "<img src='/images/ext/pdf.png' width='32' height='32' alt='pdf document' class='doc'/>", img_tag(doc)
    assert_equal "<img src='/images/ext/pdf_pv.png' width='70' height='70' alt='pdf document' class='doc'/>",  img_tag(doc, :mode=>'pv')
  end
  
  def test_img_tag_other_classes
    login(:ant)
    # contact  project       post     tag
    [:lake, :cleanWater, :opening, :art].each do |sym|
      obj   = secure!(Node) { nodes(sym) }
      klass = obj.klass
      assert_equal "<img src='/images/ext/#{klass.underscore}.png' width='32' height='32' alt='#{klass} node' class='node'/>", img_tag(obj)
      assert_equal "<img src='/images/ext/#{klass.underscore}_pv.png' width='70' height='70' alt='#{klass} node' class='node'/>",  img_tag(obj, :mode=>'pv')
    end
    
    obj   = Node.new
    assert_equal "<img src='/images/ext/other.png' width='32' height='32' alt='Node node' class='node'/>", img_tag(obj)
  end
  
  def test_img_tag_opts
    login(:anon)
    img = secure!(Node) { nodes(:bird_jpg) }
    assert_equal "<img src='/en/image30.jpg' width='660' height='600' alt='bird' id='yo' class='full'/>",
                  img_tag(img, :mode=>nil, :id=>'yo')
    assert_equal "<img src='/en/image30_pv.jpg' width='70' height='70' alt='bird' id='yo' class='super'/>",
                  img_tag(img, :mode=>'pv', :id=>'yo', :class=>'super')
    assert_equal "<img src='/en/image30_med.jpg' width='220' height='200' alt='super man' class='med'/>",
                  img_tag(img, :mode=>'med', :alt=>'super man')
  end
  
  def test_img_tag_other
    login(:tiger)
    doc = secure!(Node) { nodes(:water_pdf) }
    doc.c_ext = 'bin'
    assert_equal 'bin', doc.c_ext
    assert_equal "<img src='/images/ext/other.png' width='32' height='32' alt='bin document' class='doc'/>", img_tag(doc)
    assert_equal "<img src='/images/ext/other_pv.png' width='70' height='70' alt='bin document' class='doc'/>", img_tag(doc, :mode=>'pv')
    assert_equal "<img src='/images/ext/other.png' width='32' height='32' alt='bin document' class='doc'/>", img_tag(doc, :mode=>'std')
  end
  
  def test_alt_with_apos
    doc = secure!(Node) { nodes(:lake_jpg) }
    assert_equal "<img src='/en/projects/cleanWater/image24.jpg' width='600' height='440' alt='it&apos;s a lake' class='full'/>", img_tag(doc)
  end
  
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
  
  def test_select_id
    @node = secure!(Node) { nodes(:status) }
    select = select_id('node', :parent_id, :class=>'Project')
    assert_no_match %r{select.*node\[parent_id\].*21.*19.*29.*11}m, select
    assert_match %r{select.*node\[parent_id\].*29}, select
    login(:tiger)
    @node = secure!(Node) { nodes(:status) }
    assert_match %r{select.*node\[parent_id\].*21.*19.*29.*11}m, select_id('node', :parent_id, :class=>'Project')
    assert_match %r{input type='text'.*name.*node\[icon_id\]}m, select_id('node', :icon_id)
  end
  
  def test_date_box
    @node = secure!(Node) { nodes(:status) }
    assert_match %r{span class="date_box".*img src="\/calendar\/iconCalendar.gif".*input id='datef.*' name='node\[updated_at\]' type='text' value='2006-04-11 00:00'}m, date_box('node', 'updated_at')
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
  
  def test_trans
    assert_equal 'yoba', _('yoba')
    assert_equal '%A, %B %d %Y', _('full_date')
    GetText.set_locale_all 'fr'
    assert_equal '%A, %d %B %Y', _('full_date')
  end
  # ======================== tests pass to here ================
  def test_long_time
    atime = visitor.tz.local_to_utc(Time.utc(2006,11,10,17,42,25)) # local time for visitor
    assert_equal "17:42:25", long_time(atime)
    GetText.set_locale_all 'fr'
    assert_equal "17:42:25", long_time(atime)
  end
  
  def test_short_time
    atime = visitor.tz.local_to_utc(Time.utc(2006,11,10,17,33))
    assert_equal "17:33", short_time(atime)
    GetText.set_locale_all 'fr'
    assert_equal "17h33", short_time(atime)
  end
  
  def test_short_time_visitor_time_zone
    login(:ant) # Europe/Zurich UTC+1, DST+1
    atime = Time.utc(2008,05,18,17,33)
    assert_equal "19:33", short_time(atime)
    GetText.set_locale_all 'fr'
    assert_equal "19h33", short_time(atime)
  end

  def test_long_date
    atime = visitor.tz.utc_to_local(Time.gm(2006,11,10))
    assert_equal "2006-11-10", long_date(atime)
    GetText.set_locale_all 'fr'
    assert_equal "10.11.2006", long_date(atime)
  end

  def test_full_date
    atime = visitor.tz.utc_to_local(Time.gm(2006,11,10))
    assert_equal "Friday, November 10 2006", full_date(atime)
    GetText.set_locale_all 'fr'
    assert_equal "vendredi, 10 novembre 2006", full_date(atime)
  end
  
  def test_short_date
    atime = Time.now.utc
    visitor[:time_zone] = 'London' # utc
    assert_equal atime.strftime('%m.%d'), short_date(atime)
    GetText.set_locale_all 'fr'
    assert_equal atime.strftime('%d.%m'), short_date(atime)
  end
  
  def test_format_date
    atime = Time.now.utc
    visitor[:time_zone] = 'London' # utc
    assert_equal atime.strftime('%m.%d'), tformat_date(atime, 'short_date')
    GetText.set_locale_all 'fr'
    assert_equal atime.strftime('%d.%m'), tformat_date(atime, 'short_date')
  end
  
  def test_visitor_link
    assert_equal '', visitor_link
    login(:ant)
    assert_match %r{users/#{users_id(:ant)}.*Solenopsis Invicta}, visitor_link
  end
  
  def test_flash_messages
    login(:ant)
    assert_equal "<div id='messages'></div>", flash_messages(:show=>'both')
    flash[:notice] = 'yoba'
    assert_match /notice.*yoba/, flash_messages(:show=>'both')
    assert_no_match /error/, flash_messages(:show=>'both')
    flash[:error] = 'taio'
    assert_match /notice.*yoba/, flash_messages(:show=>'both')
    assert_match /error.*taio/, flash_messages(:show=>'both')
    flash[:notice] = nil
    assert_no_match /notice/, flash_messages(:show=>'both')
    assert_match /error/, flash_messages(:show=>'both')
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
  
  # ------ these tests were in main helper ----

  def test_check_lang_same
    GetText.set_locale_all 'en'
    obj = secure!(Node) { nodes(:zena) }
    assert_equal 'en', obj.v_lang
    assert_no_match /\[en\]/, check_lang(obj)
  end
  
  def test_check_other_lang
    visitor.lang = 'io'
    GetText.set_locale_all 'io'
    obj = secure!(Node) { nodes(:zena) }
    assert_match /\[en\]/, check_lang(obj)
  end
  
  def test_change_lang
    assert_equal ({:overwrite_params=>{:prefix=>'io'}}), change_lang('io')
    login(:ant)
    assert_equal ({:overwrite_params=>{:lang=>'io'}}), change_lang('io')
  end
  
  def test_node_actions_for_public
    @node = secure!(Node) { nodes(:cleanWater) }
    assert !@node.can_edit?, "Node cannot be edited by the public"
    res = node_actions(:actions=>:all)
    assert_equal '', res
  end
  
  def test_node_actions_wiki_public
    @node = secure!(Node) { nodes(:wiki) } 
    assert @node.can_edit?, "Node can be edited by the public"
    res = node_actions(:actions=>:all)
    assert_match %r{/nodes/29/versions/0/edit}, res
    assert_match %r{/nodes/29/edit}, res
  end
  
  def test_node_actions_for_ant
    login(:ant)
    @node = secure!(Node) { Node.find(nodes_id(:cleanWater)) }
    res = node_actions(:actions=>:all)
    assert_match    %r{/nodes/21/versions/0/edit}, res
    assert_no_match %r{/nodes/21/edit}, res
  end
  
  def test_node_actions_for_tiger
    login(:tiger)
    @node = secure!(Node) { Node.find(nodes_id(:cleanWater)) }
    res = node_actions(:actions=>:all)
    assert_match %r{/nodes/21/versions/0/edit}, res
    assert_match %r{/nodes/21/edit}, res
    @node.edit!
    assert @node.save
    res = node_actions(:actions=>:all)
    assert_match %r{/nodes/21/versions/0/edit}, res
    assert_match %r{/nodes/21/versions/0/propose}, res
    assert_match %r{/nodes/21/versions/0/publish}, res
    assert_match %r{/nodes/21/edit}, res
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
