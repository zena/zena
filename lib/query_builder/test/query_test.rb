require File.join(File.dirname(__FILE__) , 'yaml_test.rb')

class TestQuery < QueryBuilder
  
  # Relations that can be resolved without a join
  def direct_relation(txt)
    case txt
    when 'parent'
      return "#{table(main_table)}.parent_id = ID"
    when 'project'
      return "#{table(main_table)}.project_id = PROJECT_ID"
    end  
    return nil
  end
  
  # Direct filter
  def direct_filter(txt)
    if txt == 'letters'
      return "#{table(main_table)}.kpath LIKE 'NPL%'"
    end
    return nil
  end
  
  # Filters that need a join
  def relation(txt)
    if txt == 'recipients'
      add_table('links')
      add_table(main_table)
      return "#{table('links')}.relation_id = 4 AND #{table('links')}.source_id = #{table(main_table,-1)}.id AND #{table('links')}.target_id = #{table(main_table)}.id"
    else
      return nil
    end
  end

  def default_filter(clause)
    if !direct_relation(clause)
      # default direct filter is to search in the current node as parent for opened contexts
      direct_filter('parent')
    else
      nil
    end
  end
end

class QueryTest < Test::Unit::TestCase
  yaml_test :basic, :filters, :joins
  
  def parse(value)
    TestQuery.new(value).to_sql
  end
  
  make_tests
end