require File.join(File.dirname(__FILE__), "testhelp")

class NodeQueryTest < ZenaTestUnit
  yaml_dir  File.join(File.dirname(__FILE__), 'node_query')
  yaml_test :basic, :filters, :relations

  def do_test(file, test)
    context = @@test_strings[file][test]['context'] || {}
    default_context = (@@test_strings[file]['default'] || {})['context'] || {}
    context = Hash[*default_context.merge(context).map{|k,v| [k.to_sym,v]}.flatten]
    
    
    login context[:visitor].to_sym
    
    sql = NodeQuery.new(@@test_strings[file][test]['src'] || test.gsub('_',' '), context).to_sql
    
    if test_sql = @@test_strings[file][test]['sql']
      if test_sql[0..0] == "/"
        assert_match %r{#{test_sql[1..-2]}}m, sql
      else
        assert_equal test_sql, sql
      end
    end
    
    if test_res = @@test_strings[file][test]['res']
      @node = secure(Node) { nodes(context[:node].to_sym) }
      sql = eval "\"#{sql}\""
      
      res = Node.find_by_sql(sql).map {|r| r[:name]}.join(', ')
      if test_res[0..0] == "/"
        assert_match %r{#{test_res[1..-2]}}m, res
      else
        assert_equal test_res, res
      end
    end
    
  end

  make_tests
end