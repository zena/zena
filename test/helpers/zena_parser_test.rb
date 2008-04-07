require File.join(File.dirname(__FILE__), 'testhelp')

if false
  require 'ruby-debug'
  Debugger.start
end

class ZenaParserTest < ZenaTestController
  yaml_dir  File.join(File.dirname(__FILE__), 'zena_parser')
  yaml_test :relations, :basic, :zafu_ajax, :zazen, :apphelper, :errors, :data
  Section # make sure we load Section links before trying relations
  
  def setup
    @controller = TestController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    super
  end
  
  def do_test(file, test)
    src = @@test_strings[file][test]['src']
    tem = @@test_strings[file][test]['tem']
    res = @@test_strings[file][test]['res']
    context = @@test_strings[file][test]['context'] || {}
    default_context = @@test_strings[file]['default']['context'] || {'node'=>'status', 'visitor'=>'ant', 'lang'=>'en'}
    context = default_context.merge(context)
    # set context
    params = {}
    params[:user_id] = users_id(context['visitor'].to_sym)
    params[:node_id] = nodes_id(context['node'].to_sym)
    params[:prefix]  = context['lang']
    params[:url] = "/#{test.to_s.gsub('_', '/')}"
    TestController.templates = @@test_strings[file]
    if src
      post 'test_compile', params
      template = @response.body
      if tem
        if tem[0..0] == '/'
          assert_match %r{#{tem[1..-2]}}m, template
        else
          assert_equal tem, template
        end
      end
    else
      template = tem
    end
    if res
      params[:text] = template
      post 'test_render', params
      result = @response.body
      if res[0..1] == '!/'
        assert_no_match %r{#{res[2..-2]}}m, result
      elsif res[0..0] == '/'
        assert_match %r{#{res[1..-2]}}m, result
      else
        assert_equal res, result
      end
    end
  end

  def test_single
    do_test('data', 'list_values')
  end
  
  def test_basic_show_bad_attr
    # FIXME: we must do something about bad attributes : use a 'rescue' when rendering ?
    assert !Node.zafu_readable?('puts')
    assert Node.zafu_readable?('name')
  end

  def test_basic_cache_part
    with_caching do
      Node.connection.execute "UPDATE nodes SET name = 'first' WHERE id = 12;" # status
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
      Node.connection.execute "UPDATE nodes SET name = 'second' WHERE id = 12;" # status
      
      Node.logger.info cont.inspect
      post 'test_render', cont
      assert_equal 'first', @response.body
      
      Node.connection.execute "DELETE FROM #{Cache.table_name};"
      
      post 'test_render', cont
      assert_equal 'second', @response.body
    end
  end
  
  def test_relations_updated_today
    Node.connection.execute "UPDATE nodes SET updated_at = now() WHERE id IN (12, 23);" # status, art
    do_test('relations', 'updated_today')
  end
  
  def test_relations_upcoming_events
    Node.connection.execute "UPDATE nodes SET log_at = ADDDATE(curdate(), interval 1 week) WHERE id IN (2);" # people
    do_test('relations', 'upcoming_events')
  end
  
  def test_relations_in_7_days
    Node.connection.execute "UPDATE nodes SET log_at = #{Node.connection.quote(Time.now.utc)} WHERE id IN (12, 23);" # status, art
    Node.connection.execute "UPDATE nodes SET log_at = ADDDATE(curdate(), interval 6 day) WHERE id IN (8, 11);" # projects, cleanWater
    Node.connection.execute "UPDATE nodes SET log_at = ADDDATE(curdate(), interval 10 day) WHERE id IN (2);" # people
    do_test('relations', 'in_7_days')
  end
  
  def test_relations_logged_7_days_ago
    Node.connection.execute "UPDATE nodes SET log_at = now() WHERE id IN (12, 23);" # status, art
    Node.connection.execute "UPDATE nodes SET log_at = ADDDATE(curdate(), interval -6 day) WHERE id IN (8, 11);" # projects, cleanWater
    Node.connection.execute "UPDATE nodes SET log_at = ADDDATE(curdate(), interval -10 day) WHERE id IN (2);" # people
    do_test('relations', 'logged_7_days_ago')
  end
  
  def test_relations_around_7_days
    Node.connection.execute "UPDATE nodes SET log_at = now() WHERE id IN (12);" # status
    Node.connection.execute "UPDATE nodes SET log_at = ADDDATE(curdate(), interval 5 day) WHERE id IN (23);" # art
    Node.connection.execute "UPDATE nodes SET log_at = ADDDATE(curdate(), interval -6 day) WHERE id IN (8, 11);" # projects, cleanWater
    Node.connection.execute "UPDATE nodes SET log_at = ADDDATE(curdate(), interval -10 day) WHERE id IN (2);" # people
    do_test('relations', 'around_7_days')
  end
  
  def test_relations_this_week
    if Time.now.strftime('%u').to_i < 3
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval -5 day) WHERE id IN (2);" # people
      # objs in the future
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval 2 day) WHERE id IN (23);" # status, art
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval 1 day) WHERE id IN (8);" # projects, cleanWater
    else
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval 5 day) WHERE id IN (2);" # people
      # objs in the past
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval -2 day) WHERE id IN (23);" # status, art
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval -1 day) WHERE id IN (8);" # projects, cleanWater
    end  
    do_test('relations', 'this_week')    
  end
  
  def test_relations_this_month
    if Time.now.strftime('%d').to_i < 15
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval -20 day) WHERE id IN (2);" # people
      # objs in the future
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval 12 day) WHERE id IN (23);" # status, art
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval 5 day) WHERE id IN (8);" # projects, cleanWater
    else
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval 20 day) WHERE id IN (2);" # people
      # objs in the past
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval -12 day) WHERE id IN (23);" # status, art
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval -5 day) WHERE id IN (8);" # projects, cleanWater
    end  
    do_test('relations', 'this_month')    
  end
  
  def test_relations_this_year
    if Time.now.strftime('%m').to_i < 6
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval -8 month) WHERE id IN (2);" # people
      # objs in the future
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval 2 month) WHERE id IN (23);" # status, art
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval 1 month) WHERE id IN (8);" # projects, cleanWater
    else
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval 8 month) WHERE id IN (2);" # people
      # objs in the past
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval -2 month) WHERE id IN (23);" # status, art
      Node.connection.execute "UPDATE nodes SET event_at = ADDDATE(curdate(), interval -1 month) WHERE id IN (8);" # projects, cleanWater
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
  
  def test_apphelper_calendar_from_project
    login(:lion)
    @controller.instance_variable_set(:@visitor, Thread.current.visitor)
    info  = secure!(Note) { Note.create(:name=>'hello', :parent_id=>nodes_id(:collections), :log_at=>'2007-06-22')}
    assert !info.new_record?
    assert_equal nodes_id(:zena), info[:project_id]
    do_test('apphelper', 'calendar_from_project')
  end
  
  def test_basic_img_private_image
    login(:ant)
    @controller.instance_variable_set(:@visitor, Thread.current.visitor)
    node = secure!(Node) { nodes(:tree_jpg) }
    node.inherit = -1
    assert node.save
    do_test('basic', 'img_private_image')
  end
  
  def test_basic_img_image
    do_test('basic', 'img_image')
  end
  
  def test_zazen_swf_button_player
    DocumentContent.connection.execute "UPDATE document_contents SET ext = 'mp3' WHERE id = #{document_contents_id(:water_pdf)}"
    do_test('zazen', 'swf_button_player')
  end
  make_tests
end