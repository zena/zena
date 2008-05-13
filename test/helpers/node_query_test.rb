require File.join(File.dirname(__FILE__), "testhelp")

class NodeQueryTest < ZenaTestUnit
  yaml_dir  File.join(File.dirname(__FILE__), 'node_query')
  yaml_test :basic, :filters, :relations

  def do_test(file, test)
    context = @@test_strings[file][test]['context'] || {}
    default_context = (@@test_strings[file]['default'] || {})['context'] || {}
    context = Hash[*default_context.merge(context).map{|k,v| [k.to_sym,v]}.flatten]
    
    
    login context[:visitor].to_sym
    
    sql, errors = Node.build_find(:all,@@test_strings[file][test]['src'] || test.gsub('_',' '), context[:node_name])
    if test_err = @@test_strings[file][test]['err']
      if test_err[0..0] == "/"
        assert_match %r{#{test_err[1..-2]}}m, errors.join(", ")
      else
        assert_equal test_err, errors.join(", ")
      end
    else
      sql ||= errors.join(", ")
      if test_sql = @@test_strings[file][test]['sql']
        if test_sql[0..0] == "/"
          assert_match %r{#{test_sql[1..-2]}}m, sql
        else
          assert_equal test_sql, sql
        end
      end
    
      if errors == [] && test_res = @@test_strings[file][test]['res']
        @node = secure(Node) { nodes(context[:node].to_sym) }
        sql = eval "\"#{sql}\""
      
        res = @node.do_find(:all, sql)
        res = res ? res.map {|r| r[:name]}.join(', ') : ''
        if test_res && test_res[0..0] == "/"
          assert_match %r{#{test_res[1..-2]}}m, res
        else
          assert_equal test_res, res
        end
      end
    end
    
  end

  make_tests
end