require File.join(File.dirname(__FILE__) , '..', '..', 'yaml_test.rb')
require File.join(File.dirname(__FILE__) , '..', 'lib', 'query_builder')

class TestQuery < QueryBuilder
  
  # Build joins and filters from a relation.
  def relation(txt)
    direct_relation(txt) ||
    direct_filter(txt)   ||
    join_relation(txt)
  end
  
  # default relation filter is to search in the current node's children
  def default(clause)
    if clause == main_table || direct_filter(clause)
      'parent'
    elsif join_relation(clause)
      main_table
    else
      nil
    end
  end
  
  private
    
    # Root filters (relations that can be solved without a join).
    def direct_relation(txt)
      case txt
      when 'parent'
        "#{map_field('parent_id')} = #{map_field('id', table(main_table,-1), 'id')}"
      when 'project'
        "#{map_field('project_id')} = #{map_field('id', table(main_table,-1), 'project_id')}"
      when 'site', main_table
        nil
      else
        nil
      end
    end

    # Direct filter
    def direct_filter(txt)
      case txt
      when 'letters'
        "#{table}.kpath LIKE 'NNL%'"
      else
        nil
      end
    end

    # Filters that need a join
    def join_relation(txt)
      case txt
      when 'recipients'
        add_table('links')
        add_table(main_table)
        "#{table('links')}.relation_id = 4 AND #{table('links')}.source_id = #{table(main_table,-1)}.id AND #{table('links')}.target_id = #{table}.id"# #{map_field('id', table(main_table,-1), 'project_id')}
      else
        nil
      end
    end
end

class QueryTest < Test::Unit::TestCase
  yaml_dir File.dirname(__FILE__)
  yaml_test :basic, :filters, :joins
  
  def parse(value, opts)
    TestQuery.new(value).to_sql
  end
  
  make_tests
end