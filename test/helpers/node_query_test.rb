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

  make_tests
end