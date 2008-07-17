require File.join(File.dirname(__FILE__), "testhelp")

class NodeQueryTest < ZenaTestUnit
  yaml_test

  def do_test(file, test)
    context = @@test_strings[file][test]['context'] || {}
    default_context = (@@test_strings[file]['default'] || {})['context'] || {}
    context = Hash[*default_context.merge(context).map{|k,v| [k.to_sym,v]}.flatten]
    
    params = {}
    (context[:params] || {}).each do |k,v|
      params[k.to_sym] = v
    end
    
    $_test_site = params[:site] || 'zena'
    login context[:visitor].to_sym
    
    sql, errors = Node.build_find(:all,@@test_strings[file][test]['src'] || test.gsub('_',' '), context)
    if test_err = @@test_strings[file][test]['err']
      assert_yaml_test test_err, errors.join(", ")
    else
      sql ||= errors.join(", ")
      if test_sql = @@test_strings[file][test]['sql']
        test_sql.gsub!(/_ID\(([^\)]+)\)/) do
          ZenaTest::id($_test_site, $1)
        end
        assert_yaml_test test_sql, sql
      end
    
      if test_res = @@test_strings[file][test]['res']
        if errors == []
          @node = secure(Node) { nodes(context[:node].to_sym) }
          sql = eval "\"#{sql}\""
      
          res = @node.do_find(:all, sql)
          res = res ? res.map {|r| r[:name]}.join(', ') : ''
          assert_yaml_test test_res, res
        else
          assert_yaml_test test_res, errors.join(", ")
        end
      end
    end
    
  end
  
  def test_find_new_record
    login(:tiger)
    node = secure!(Node) { Node.new }
    assert_equal nil, node.find(:all,'set_tags')
    node = secure!(Node) { Node.get_class('Tag').new_instance }
    assert_equal nil, node.find(:all,'tagged')
  end
  
  def test_do_find_in_new_node
    login(:tiger)
    assert var1_new = secure!(Node) { Node.get_class("Post").new }
    assert_nil var1_new.do_find(:all, eval("\"#{Node.build_find(:all, 'posts in site', :node_name => 'self')}\""))
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
    tagged = node.find(:all, 'tagged')
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
    tagged = node.find(:all, 'tagged')
    # cleanWater, opening
    assert_equal [nil, "cold"], tagged.map{|t| t.l_comment}
  end

  make_tests
end