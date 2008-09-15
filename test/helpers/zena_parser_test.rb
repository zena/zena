require File.join(File.dirname(__FILE__), 'testhelp')

if false
  require 'ruby-debug'
  Debugger.start
end

class ZenaParserTest < ZenaTestController
  yaml_test
  Section # make sure we load Section links before trying relations
  
  def setup
    @controller = TestController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    $_test_site = 'zena'
    super
  end
  
  def do_test(file, test)
    src = @@test_strings[file][test]['src']
    tem = @@test_strings[file][test]['tem']
    res = @@test_strings[file][test]['res']
    compiled_files = {}
    @@test_strings[file][test].each do |k,v|
      next if ['src','tem','res','context'].include?(k)
      compiled_files[k] = v
    end
    context = @@test_strings[file][test]['context'] || {}
    default_context = @@test_strings[file]['default']['context'] || {'node'=>'status', 'visitor'=>'ant', 'lang'=>'en'}
    context = default_context.merge(context)
    # set context
    params = {}
    $_test_site = context.delete('site') || 'zena'
    @request.host = sites_host($_test_site)
    params[:user_id] = users_id(context.delete('visitor').to_sym)
    params[:node_id] = nodes_id(context.delete('node').to_sym)
    params[:prefix]  = context.delete('lang')
    params[:date]    = context['ref_date'] ? context.delete('ref_date').to_s : nil
    params[:url] = "/#{test.to_s.gsub('_', '/')}"
    params.merge!(context) # merge the rest of the context as query parameters
    TestController.templates = @@test_strings[file]
    if src
      post 'test_compile', params
      template = @response.body
      if tem
        assert_yaml_test tem, template
      end
    else
      template = tem
    end
    
    compiled_files.each do |path,value|
      fullpath = File.join(SITES_ROOT,'test.host','zafu',path)
      assert File.exist?(fullpath), "Saved template #{path} should exist."
      assert_yaml_test value, File.read(fullpath)
    end
    
    if res
      params[:text] = template
      post 'test_render', params
      result = @response.body
      assert_yaml_test res, result
    end
  end
  
  alias o_assert_yaml_test assert_yaml_test
  
  def assert_yaml_test(test_val, result)
    test_val.gsub!(/_ID\(([^\)]+)\)/) do
        ZenaTest::id($_test_site, $1)
    end
    o_assert_yaml_test test_val, result
  end
  
  def test_basic_show_bad_attr
    # FIXME: we must do something about bad attributes : use a 'rescue' when rendering ?
    assert !Node.zafu_readable?('puts')
    assert Node.zafu_readable?('name')
  end

  def test_basic_cache_part
    with_caching do
      Node.connection.execute "UPDATE nodes SET name = 'first' WHERE id = #{nodes_id(:status)}"
      caches = Cache.find(:all)
      assert_equal [], caches
      do_test('basic', 'cache_part')
      
      cont = {
        :user_id => users_id(:anon),
        :node_id => nodes_id(:status),
        :prefix  => 'en',
        :url  => '/cache/part',
        :text => @response.body
      }.freeze
      
      post 'test_render', cont
      assert_equal 'first', @response.body
      
      cache  = Cache.find(:first)
      assert_kind_of Cache, cache
      assert_equal "first", cache.content
      Node.connection.execute "UPDATE nodes SET name = 'second' WHERE id = #{nodes_id(:status)}"
      
      post 'test_render', cont
      assert_equal 'first', @response.body
      
      Node.connection.execute "DELETE FROM #{Cache.table_name};"
      
      post 'test_render', cont
      assert_equal 'second', @response.body
    end
  end
  
  def test_relations_updated_today
    Node.connection.execute "UPDATE nodes SET updated_at = now() WHERE id IN (#{nodes_id(:status)}, #{nodes_id(:art)});"
    do_test('relations', 'updated_today')
  end
  
  def test_relations_upcoming_events
    Node.connection.execute "UPDATE nodes SET log_at = ADDDATE(curdate(), interval 1 week) WHERE id IN (#{nodes_id(:people)})"
    do_test('relations', 'upcoming_events')
  end
  
  def test_relations_in_7_days
    Node.connection.execute "UPDATE nodes SET log_at = curdate() WHERE id IN (#{nodes_id(:status)}, #{nodes_id(:art)})"
    Node.connection.execute "UPDATE nodes SET log_at = curdate() + interval 6 day WHERE id IN (#{nodes_id(:projects)}, #{nodes_id(:cleanWater)})"
    Node.connection.execute "UPDATE nodes SET log_at = curdate() + interval 10 day WHERE id IN (#{nodes_id(:people)})"
    do_test('relations', 'in_7_days')
  end
  
  def test_relations_logged_7_days_ago
    Node.connection.execute "UPDATE nodes SET log_at = now() WHERE id IN (#{nodes_id(:status)}, #{nodes_id(:art)})"
    Node.connection.execute "UPDATE nodes SET log_at = curdate() - interval 6 day WHERE id IN (#{nodes_id(:projects)}, #{nodes_id(:cleanWater)})"
    Node.connection.execute "UPDATE nodes SET log_at = curdate() - interval 10 day WHERE id IN (#{nodes_id(:people)});"
    do_test('relations', 'logged_7_days_ago')
  end
  
  def test_relations_around_7_days
    Node.connection.execute "UPDATE nodes SET log_at = now() WHERE id IN (#{nodes_id(:status)});"
    Node.connection.execute "UPDATE nodes SET log_at = curdate() + interval 5 day WHERE id IN (#{nodes_id(:art)});"
    Node.connection.execute "UPDATE nodes SET log_at = curdate() - interval 6 day WHERE id IN (#{nodes_id(:projects)}, #{nodes_id(:cleanWater)});"
    Node.connection.execute "UPDATE nodes SET log_at = curdate() - interval 10 day WHERE id IN (#{nodes_id(:people)});"
    do_test('relations', 'around_7_days')
  end
  
  def test_relations_in_37_hours
    Node.connection.execute "UPDATE nodes SET log_at = #{Node.connection.quote(Time.now.utc)} WHERE id IN (#{nodes_id(:art)});" # art
    Node.connection.execute "UPDATE nodes SET log_at = curdate() + interval 36 hour WHERE id IN (#{nodes_id(:cleanWater)})"
    Node.connection.execute "UPDATE nodes SET log_at = curdate() + interval 38 hour WHERE id IN (#{nodes_id(:projects)}, 2);" # projects, people
    do_test('relations', 'in_37_hours')
  end
  
  def test_relations_this_week
    if Time.now.strftime('%u').to_i < 3
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval -5 day) WHERE id IN (#{nodes_id(:people)});" # people
      # objs in the future
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval 2 day) WHERE id IN (#{nodes_id(:art)});" # status, art
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval 1 day) WHERE id IN (#{nodes_id(:projects)});" # projects, cleanWater
    else
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval 5 day) WHERE id IN (#{nodes_id(:people)});" # people
      # objs in the past
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval -2 day) WHERE id IN (#{nodes_id(:art)});" # status, art
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval -1 day) WHERE id IN (#{nodes_id(:projects)});" # projects, cleanWater
    end  
    do_test('relations', 'this_week')    
  end
  
  def test_relations_this_month
    if Time.now.strftime('%d').to_i < 15
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval -20 day) WHERE id IN (#{nodes_id(:people)});" # people
      # objs in the future
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval 12 day) WHERE id IN (#{nodes_id(:art)});" # status, art
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval 5 day) WHERE id IN (#{nodes_id(:projects)});" # projects, cleanWater
    else
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval 20 day) WHERE id IN (#{nodes_id(:people)});" # people
      # objs in the past
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval -12 day) WHERE id IN (#{nodes_id(:art)});" # status, art
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval -5 day) WHERE id IN (#{nodes_id(:projects)});" # projects, cleanWater
    end  
    do_test('relations', 'this_month')    
  end
  
  def test_relations_this_year
    if Time.now.strftime('%m').to_i < 6
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval -8 month) WHERE id IN (#{nodes_id(:people)});" # people
      # objs in the future
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval 2 month) WHERE id IN (#{nodes_id(:art)});" # status, art
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval 1 month) WHERE id IN (#{nodes_id(:projects)});" # projects, cleanWater
    else
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval 8 month) WHERE id IN (#{nodes_id(:people)});" # people
      # objs in the past
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval -2 month) WHERE id IN (#{nodes_id(:art)});" # status, art
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval -1 month) WHERE id IN (#{nodes_id(:projects)});" # projects, cleanWater
    end
    do_test('relations', 'this_year')    
  end
  
  def test_relations_direction_both
    "art, projects, status"
    art, projects, status = nodes_id(:art), nodes_id(:projects), nodes_id(:status)
    values = [
      "(#{art},#{status},#{relations_id(:node_has_references)})",
      "(#{status},#{projects},#{relations_id(:node_has_references)})"
      ]
    Node.connection.execute "INSERT INTO links (`source_id`,`target_id`,`relation_id`) VALUES #{values.join(',')}"
    do_test('relations', 'direction_both')
  end
  
  def test_relations_direction_both_self_auto_ref
    "art, projects, status"
    art, projects, status = nodes_id(:art), nodes_id(:projects), nodes_id(:status)
    values = [
      "(#{art},#{status},#{relations_id(:node_has_references)})",
      "(#{status},#{status},#{relations_id(:node_has_references)})",
      "(#{status},#{projects},#{relations_id(:node_has_references)})"
      ]
    Node.connection.execute "INSERT INTO links (`source_id`,`target_id`,`relation_id`) VALUES #{values.join(',')}"
    do_test('relations', 'direction_both_self_auto_ref')
  end
  
  #def test_apphelper_calendar_from_project
  #  login(:lion)
  #  @controller.instance_variable_set(:@visitor, Thread.current.visitor)
  #  info  = secure!(Note) { Note.create(:name=>'hello', :parent_id=>nodes_id(:collections), :log_at=>'2007-06-22')}
  #  assert !info.new_record?
  #  assert_equal nodes_id(:zena), info[:project_id]
  #  do_test('apphelper', 'calendar_from_project')
  #end
  
  def test_basic_img_private_image
    login(:ant)
    @controller.instance_variable_set(:@visitor, Thread.current.visitor)
    node = secure!(Node) { nodes(:tree_jpg) }
    node.inherit = -1
    assert node.save
    do_test('basic', 'img_private_image')
  end
  
  def test_basic_recursion_in_each
    Node.connection.execute "UPDATE nodes SET max_status = 40 WHERE id = #{nodes_id(:status)}"
    Node.connection.execute "UPDATE versions SET status = 40 WHERE node_id = #{nodes_id(:status)}"
    do_test('basic', 'recursion_in_each')
  end
  
  def test_zazen_swf_button_player
    DocumentContent.connection.execute "UPDATE document_contents SET ext = 'mp3' WHERE id = #{document_contents_id(:water_pdf)}"
    do_test('zazen', 'swf_button_player')
  end
  
  def test_basic_captcha
    Site.connection.execute "INSERT INTO site_attributes (`key`,`value`,`owner_id`) VALUES ('recaptcha_pub','pubkey', #{sites_id(:zena)}), ('recaptcha_priv','privkey',#{sites_id(:zena)})"
    do_test('basic', 'captcha')
  end
  make_tests
end