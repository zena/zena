require File.join(File.dirname(__FILE__), "testhelp")

class NodeQueryTest < ZenaTestUnit
  yaml_dir  File.join(File.dirname(__FILE__), 'node_query')
  yaml_test :basic, :filters, :relations

  def do_test(file, test)
    context = @@test_strings[file][test]['context'] || {}
    default_context = (@@test_strings[file]['default'] || {})['context'] || {}
    context = Hash[*default_context.merge(context).map{|k,v| [k.to_sym,v]}.flatten]
    
    params = {}
    (context[:params] || {}).each do |k,v|
      params[k.to_sym] = v
    end
    
    login context[:visitor].to_sym
    
    sql, errors = Node.build_find(:all,@@test_strings[file][test]['src'] || test.gsub('_',' '), context[:node_name])
    if test_err = @@test_strings[file][test]['err']
      assert_yaml_test test_err, errors.join(", ")
    else
      sql ||= errors.join(", ")
      if test_sql = @@test_strings[file][test]['sql']
        assert_yaml_test test_sql, sql
      end
    
      if errors == [] && test_res = @@test_strings[file][test]['res']
        @node = secure(Node) { nodes(context[:node].to_sym) }
        sql = eval "\"#{sql}\""
      
        res = @node.do_find(:all, sql)
        res = res ? res.map {|r| r[:name]}.join(', ') : ''
        assert_yaml_test test_res, res
      end
    end
    
  end

  make_tests
end