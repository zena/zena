require 'test_helper'

class ZafuCompilerTest < Zena::Controller::TestCase
 OK = %w{
    action
    asset
    conditional
    dates
    display
    errors
    i18n
    off
    recursion
    relations
    roles
    rubyless
    safe_definitions
    search
    site
    urls
    user
    version
    workflow
    zafu_attributes
    zazen
  }

  BUG = %w{
    ajax
    apphelper
    basic
    complex
    data
    eval
    forms
    security
  }

  LATER = %w{later}

  yamltest :directories => [:default, "#{Zena::ROOT}/bricks/**/test/zafu"] #, :files => ['conditional']

  Section # make sure we load Section links before trying relations

  class ZafuDummy
    include RubyLess
    safe_method [:hello, {:lang => String}] => String

    def hello(opts)
      case opts[:lang]
      when 'en'
        'Hi there!'
      when 'fr'
        'Salut poilu!'
      when 'de'
        'Grützi!'
      else
        "Sorry, I don't speak #{opts[:lang]}..."
      end
    end
  end

  class ::Node
    def dummy
      ZafuDummy.new
    end
  end

  RubyLess::SafeClass.safe_method_for Node, [:dummy] => ZafuDummy

  def setup
    @controller = Zena::TestController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    super
  end

  def yt_do_test(file, test)
    # Disable defined tests without loaded files
    return unless (@@test_strings[file] || {})[test]

    if @@test_strings[file][test].keys.include?('src')
      # we do not want src built from title
      src = yt_get('src', file, test)
    elsif src = yt_get('eval', file, test)
      src = @@test_strings[file][test]['src'] = "<r:eval>#{src}</r:eval>"
    end

    tem = yt_get('tem', file, test)
    res = yt_get('res', file, test)
    js  = yt_get('js',  file, test)

    compiled_files = {}
    @@test_strings[file][test].each do |k,v|
      next if ['src','tem','res','context','eval','js'].include?(k) || k =~ /^old/
      compiled_files[k] = v
    end
    context = yt_get('context', file, test)
    site = sites(context.delete('site') || 'zena')
    $_test_site = site.name
    @request.host = site.host
    # set context
    params = {}
    #params[:user_id] = users_id(context.delete('visitor').to_sym)
    params['user'] = context.delete 'visitor'
    params['node_id'] = nodes_id(context.delete('node').to_sym)
    params['prefix']  = context.delete('lang')
    params['date']    = context['ref_date'] ? context.delete('ref_date').to_s : nil
    params['url'] = "#{file}/#{test.to_s.gsub('_', '/')}"
    params.merge!(context) # merge the rest of the context as query parameters
    Zena::TestController.templates = @@test_strings[file]
    if src
      post 'test_compile', params
      template = @response.body
      if tem
        yt_assert tem, template
      end
    else
      template = tem
    end

    compiled_files.each do |path,value|
      fullpath = File.join(SITES_ROOT,'test.host','zafu',path)
      assert File.exist?(fullpath), "Saved template #{path} should exist."
      yt_assert value, File.read(fullpath)
    end

    if res
      params['text'] = template
      post 'test_render', params
      result = @response.body
      yt_assert res, result
      if js
        yt_assert js, @controller.send(:render_js)
      end
    elsif js
      params['text'] = template
      post 'test_render', params
      yt_assert js, @controller.send(:render_js)
    end
  end

  alias o_yt_assert yt_assert

  def yt_assert(test_val, result)
    test_val.gsub!(/_ID\(([^\)]+)\)/) do
      Zena::FoxyParser::id($_test_site, $1)
    end
    o_yt_assert test_val, result
  end

  # turned part caching off
  # def test_basic_cache_part
  #   test_site('zena')
  #   with_caching do
  #     Node.connection.execute "UPDATE nodes SET node_name = 'first' WHERE id = #{nodes_id(:status)}"
  #     caches = Cache.find(:all)
  #     assert_equal [], caches
  #     yt_do_test('basic', 'cache_part')
  #
  #     cont = {
  #       :user_id => users_id(:anon),
  #       :user => 'anon',
  #       :node_id => nodes_id(:status),
  #       :prefix  => 'en',
  #       :url  => '/cache/part',
  #       :text => @response.body
  #     }.freeze
  #
  #     post 'test_render', cont
  #     assert_equal 'first', @response.body
  #
  #     cache  = Cache.find(:first)
  #     assert_kind_of Cache, cache
  #     assert_equal "first", cache.content
  #     Node.connection.execute "UPDATE nodes SET node_name = 'second' WHERE id = #{nodes_id(:status)}"
  #
  #     post 'test_render', cont
  #     assert_equal 'first', @response.body
  #
  #     Node.connection.execute "DELETE FROM #{Cache.table_name};"
  #
  #     post 'test_render', cont
  #     assert_equal 'second', @response.body
  #   end
  # end

  def test_relations_updated_today
    test_site('zena')
    Node.connection.execute "UPDATE nodes SET updated_at = #{Zena::Db::NOW} WHERE id IN (#{nodes_id(:status)}, #{nodes_id(:art)});"
    yt_do_test('relations', 'updated_today')
  end

  def test_relations_upcoming_events
    set_date(:people, :days => 7)
    yt_do_test('relations', 'upcoming_events')
  end

  def test_relations_in_7_days
    set_date(:art)
    set_date([:projects, :cleanWater], :days => 6)
    set_date([:people],                :days => 10)
    yt_do_test('relations', 'in_7_days')
  end

  def test_relations_logged_7_days_ago
    set_date([:art, :status], :minutes => 2)
    set_date([:projects, :cleanWater], :days => -6)
    set_date([:people],                :days => -10)
    yt_do_test('relations', 'logged_7_days_ago')
  end

  def test_relations_around_7_days
    set_date(:status)
    set_date(:art,                     :days => 5)
    set_date([:projects, :cleanWater], :days => -6)
    set_date([:people],                :days => -10)
    yt_do_test('relations', 'around_7_days')
  end

  def test_relations_in_37_hours
    set_date(:art, :minutes => 2)
    set_date(:cleanWater,          :hours => 36)
    set_date([:projects, :people], :hours => 38)
    yt_do_test('relations', 'in_37_hours')
  end

  def test_relations_this_week
    if Time.now.strftime('%u').to_i < 3
      # not in this week
      set_date(:people,   :days => -5, :fld => 'event_at')
      # in this week
      set_date(:art,      :days =>  2, :fld => 'event_at')
      set_date(:projects, :days =>  1, :fld => 'event_at')
    else
      # not in this week
      set_date(:people,   :days =>  5, :fld => 'event_at')
      # in this week
      set_date(:art,      :days => -2, :fld => 'event_at')
      set_date(:projects, :days => -1, :fld => 'event_at')
    end
    yt_do_test('relations', 'this_week')
  end

  def test_relations_this_month
    if Time.now.strftime('%d').to_i < 15
      # not in this month
      set_date(:people,   :days => -20, :fld => 'event_at')
      # in this month
      set_date(:art,      :days =>  12, :fld => 'event_at')
      set_date(:projects, :days =>   5, :fld => 'event_at')
    else
      # not in this month
      set_date(:people,   :days =>  20, :fld => 'event_at')
      # in this month
      set_date(:art,      :days => -12, :fld => 'event_at')
      set_date(:projects, :days =>  -5, :fld => 'event_at')
    end
    yt_do_test('relations', 'this_month')
  end

  def test_relations_this_year
    if Time.now.strftime('%m').to_i < 6
      # not in this year
      set_date(:people,   :months => -8, :fld => 'event_at')
      # in this year
      set_date(:art,      :months =>  2, :fld => 'event_at')
      set_date(:projects, :months =>  1, :fld => 'event_at')
    else
      # not in this year
      set_date(:people,   :months =>  8, :fld => 'event_at')
      # in this year
      set_date(:art,      :months => -2, :fld => 'event_at')
      set_date(:projects, :months => -1, :fld => 'event_at')
    end
    yt_do_test('relations', 'this_year')
  end

  def test_relations_direction_both
    test_site('zena')
    art, projects, status = nodes_id(:art), nodes_id(:projects), nodes_id(:status)
    values = [
      [art,    status,   relations_id(:node_has_references)],
      [status, projects, relations_id(:node_has_references)]
      ]
    Zena::Db.insert_many('links', %W{source_id target_id relation_id}, values)
    yt_do_test('relations', 'direction_both')
  end

  def test_relations_direction_both_self_auto_ref
    test_site('zena')
    art, projects, status = nodes_id(:art), nodes_id(:projects), nodes_id(:status)
    values = [
      [art,    status,   relations_id(:node_has_references)],
      [status, status,   relations_id(:node_has_references)],
      [status, projects, relations_id(:node_has_references)]
      ]
    Zena::Db.insert_many('links', %W{source_id target_id relation_id}, values)
    yt_do_test('relations', 'direction_both_self_auto_ref')
  end

  def test_recursion_in_each
    login(:tiger)
    node = secure!(Node) { nodes(:status) }
    node.unpublish
    yt_do_test('recursion', 'in_each')
  end

  def test_zazen_swf_button_player
    login(:tiger)
    node = secure!(Node) { nodes(:water_pdf) }
    node.prop['ext'] = 'mp3'
    node.send(:dump_properties)
    Zena::Db.execute "UPDATE versions SET properties = #{Zena::Db.quote(node.version[:properties])}"
    yt_do_test('zazen', 'swf_button_player')
  end

  def test_basic_captcha
    values = [
      ["'recaptcha_pub'", "'pubkey'", sites_id(:zena)],
      ["'recaptcha_priv'", "'privkey'", sites_id(:zena)]
    ]
    Zena::Db.insert_many('site_attributes', %W{key value owner_id}, values)
    yt_do_test('basic', 'captcha')
  end

  def test_dates_uses_datebox_missing_lang
    login(:ant)
    visitor.lang = 'io'
    yt_do_test('dates', 'uses_datebox_missing_lang')
  end

  def test_display_defined_icon
    return unless test = (@@test_strings['display'] || {})['defined_icon']
    login(:tiger)
    # define flower as icon
    node = secure!(Node) { nodes(test['context']['node'].to_sym)}
    assert node.update_attributes(:icon_id => nodes_id(:flower_jpg))
    yt_do_test('display', 'defined_icon')
  end

  def test_relations_same_name_as_class
    login(:lion)
    rel = Relation.create(
      :source_kpath => 'NP',
      :source_role  => '',
      :target_kpath => 'NNL',
      :target_role  => 'live_letter'
    )
    assert !rel.new_record?
    yt_do_test('relations', 'same_name_as_class')
  end

  yt_make
end