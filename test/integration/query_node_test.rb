require 'test_helper'
require 'yamltest'

class QueryNodeTest < Zena::Unit::TestCase
  include RubyLess
  safe_method :date => Time
  safe_method :params => StringDictionary

  def safe_method_type(signature, receiver = nil)
    # TODO: we could use the @context[:node] to get real class..
    if type = Node.safe_method_type(signature)
      type.merge(:method => "@node.#{type[:method]}")
    else
      super
    end
  end

  def date
    @context[:date]
  end

  def start_node_zip
    @node.zip
  end

  # ========== YAML TESTS
  yamltest

  def yt_do_test(file, test)
    @context = Hash[*(yt_get('context', file, test).map{|k,v| [k.to_sym, v]}.flatten)]

    if @context[:date]
      @context[:date] = @context[:date].to_utc('%Y-%m-%d %H:%M:%S', @context[:tz] ? TZInfo::Timezone.get(@context[:tz]) : visitor.tz)
    end

    params = {}
    (@context[:params] || {}).each do |k,v|
      params[k.to_sym] = v
    end

    $_test_site = @context[:site] || 'zena'
    login(@context[:visitor].to_sym, $_test_site)

    @context[:rubyless_helper] = self
    defaults = (@context[:default] ||= {})
    defaults[:order] ||= 'zip asc'

    if klass = @context.delete(:class)
      @context[:main_class] = VirtualClass[klass]
    end

    begin
      query  = Node.build_query(:all, yt_get('src', file, test), @context)
      sql, node_class = query.to_s, query.main_class
    rescue ::QueryBuilder::Error => err
      errors = err.message
    end

    class_prefix = (node_class && !(node_class <= Node)) ? "#{node_class}: " : ''

    if test_err = yt_get('err', file, test)
      yt_assert test_err, class_prefix + errors
    else
      sql ||= class_prefix + errors
      if test_sql = yt_get(Zena::Db.adapter, file, test) || yt_get('sql', file, test)
        test_sql.gsub!(/_ID\(([^\)]+)\)/) do
          Zena::FoxyParser::id($_test_site, $1)
        end
        yt_assert test_sql, class_prefix + sql
      end

      if test_res = @@test_strings[file][test]['res']
        if !errors
          @node = secure(Node) { nodes(@context[:node].to_sym) }
          sql = eval sql

          res = node_class.do_find(:all, sql)

          res = res ? res.map(&:title).join(', ') : ''

          yt_assert test_res, class_prefix + res
        else
          yt_assert test_res, class_prefix + errors
        end
      end
    end

  end

  def test_find_new_record
    login(:tiger)
    node = secure!(Node) { Node.new }
    assert_equal nil, node.find(:all,'set_tags')
    node = secure!(Node) { Node.get_class('Tag').new_instance }
    assert_equal nil, node.find(:all,'tagged', :skip_rubyless => true)
  end

  def test_do_find_in_new_node
    login(:tiger)
    assert var1_new = secure!(Node) { Node.get_class("Post").new_instance }
    sql = Node.build_query(:all, 'posts', :node_name => 'var1_new').to_s
    assert_nil Node.do_find(:all, eval(sql))
  end

  def test_link_id
    login(:tiger)
    page = secure!(Node) { nodes(:cleanWater) }
    pages = page.find(:all, 'pages')
    assert_nil pages[0].link_id
    tags  = page.find(:all, 'set_tags')
    assert_equal [links_id(:cleanWater_in_art).to_s], tags.map{|r| r.link_id}
  end

  def test_do_find_bad_relation
    login(:lion)
    node = secure!(Node) { nodes(:status) }
    assert_nil node.find(:first, 'blah')
  end

  def test_l_status
    login(:lion)
    node = secure!(Node) { nodes(:art) }
    tagged = node.find(:all, 'tagged', :skip_rubyless => true)
    # cleanWater, opening
    assert_equal [10, 5], tagged.map{|t| t.l_status}
  end

  def test_l_comment
    login(:lion)
    node = secure!(Node) { nodes(:opening) }
    tagged = node.find(:all, 'set_tags')
    # art, news
    assert_equal ["cold", "hot"], tagged.map{|t| t.l_comment}
  end

  def test_l_comment_empty
    login(:lion)
    node = secure!(Node) { nodes(:art) }
    tagged = node.find(:all, 'tagged', :skip_rubyless => true)
    # cleanWater, opening
    assert_equal [nil, "cold"], tagged.map{|t| t.l_comment}
  end

  def test_find_count
    login(:ant)
    page = secure!(Node) { nodes(:cleanWater) }

    sql = Node.build_query(:all, 'nodes where title like "a%" in site').to_s(:count)
    assert_equal 3, Node.do_find(:count, eval(sql))
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

  def test_relations_same_name_as_class_in_site
    login(:lion)
    rel = Relation.create(
      :source_kpath => 'NP',
      :source_role  => '',
      :target_kpath => 'NNL',
      :target_role  => 'live_letter'
    )
    assert !rel.new_record?
    yt_do_test('relations', 'same_name_as_class_in_site')
  end

  def test_relations_same_name_as_class_not_valid
    login(:lion)
    rel = Relation.create(
      :source_kpath => 'NP',
      :source_role  => '',
      :target_kpath => 'NNL',
      :target_role  => 'live_letter'
    )
    assert !rel.new_record?
    yt_do_test('relations', 'same_name_as_class_not_valid')
  end

  yt_make
end