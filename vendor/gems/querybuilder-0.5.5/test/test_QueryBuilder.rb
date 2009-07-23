require File.dirname(__FILE__) + '/test_helper.rb'


class DummyQueryBuilder < Test::Unit::TestCase
  yamltest
  
  def id;         123;  end
  def parent_id;  333;  end
  def project_id; 9999; end
  def connection; self; end
  
  
  def yt_parse(key, source, opts)
    opts = Hash[*(opts.map{|k,v| [k.to_sym, v]}.flatten)]
    query = DummyQuery.new(source, opts)
    
    case key
    when 'res'
      (query.main_class != DummyQueryClass ? "#{query.main_class.to_s}: " : '') + if res = query.to_s
        res
      else
        query.errors.join(", ")
      end
    when 'sql'
      query.sql(binding)
    when 'count'
      query.to_s(:count)
    when 'count_sql'
      query.sql(binding, :count)
    else
      "parse not implemented for '#{key}' in query_builder_test.rb"
    end
  end
  
  yt_make
end