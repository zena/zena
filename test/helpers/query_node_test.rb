require 'test_helper'
require 'yamltest'

class QueryNodeTest < Zena::Unit::TestCase
  yamltest
  def yt_do_test(file, test)
    context = Hash[*(yt_get('context', file, test).map{|k,v| [k.to_sym, v]}.flatten)]

    params = {}
    (context[:params] || {}).each do |k,v|
      params[k.to_sym] = v
    end

    $_test_site = params[:site] || 'zena'
    login context[:visitor].to_sym

    query = Node.build_find(:all, yt_get('src', file, test), context)
    sql, errors, uses_node_name, node_class = query.to_s, query.errors, query.uses_node_name, query.main_class
    class_prefix = (node_class != Node ? "#{node_class.to_s}: " : '')

    if test_err = yt_get('err', file, test)
      yt_assert test_err, class_prefix + errors.join(", ")
    else
      sql ||= class_prefix + errors.join(", ")
      if test_sql = yt_get(Zena::Db.adapter, file, test) || yt_get('sql', file, test)
        test_sql.gsub!(/_ID\(([^\)]+)\)/) do
          Zena::FoxyParser::id($_test_site, $1)
        end
        yt_assert test_sql, class_prefix + sql
      end

      if test_res = @@test_strings[file][test]['res']
        if errors == []
          @node = secure(Node) { nodes(context[:node].to_sym) }
          sql = eval sql

          res = @node.do_find(:all, sql, uses_node_name, node_class)

          if node_class == Comment
            res = res ? res.map {|r| r[:title]}.join(', ') : ''
          else
            res = res ? res.map {|r| r[:name]}.join(', ') : ''
          end

          yt_assert test_res, class_prefix + res
        else
          yt_assert test_res, class_prefix + errors.join(", ")
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
    assert var1_new = secure!(Node) { Node.get_class("Post").new }
    sql = Node.build_find(:all, 'posts in site', :node_name => 'self').sql(binding)
    assert_nil var1_new.do_find(:all, eval("\"#{sql}\""))
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
    sql = Node.build_find(:all, 'nodes where name like "a%" in site', :node_name => 'self').to_s(:count)
    assert_equal 3, page.do_find(:count, eval(sql))
  end

  yt_make
end