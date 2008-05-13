require File.join(File.dirname(__FILE__) , '..', '..', 'yaml_test.rb')
require File.join(File.dirname(__FILE__) , '..', 'lib', 'query_builder')
require 'ruby-debug'
Debugger.start

class TestQuery < QueryBuilder
  
  # Build joins and filters from a relation.
  def relation(rel)
    context_relation(rel) ||
    direct_filter(rel)   ||
    join_relation(rel)
  end
  
  # default context filter is to search in the current node's children (in self)
  def default_context_filter(clause)
    if direct_filter?(clause)
      # we add the default scope if the relation can be resolved with a 'where' clause.
      'self'
    else
      nil
    end
  end
  
  private
    # Root filters (relations that can be solved without a join). Think 'in clause' (in self, in parent).
    def context_filter_fields(clause)
      case clause
      when 'self'
        ['parent_id', 'id']
      when 'parent'
        ['parent_id', 'parent_id']
      when 'project'
        ['project_id', 'project_id']
      when 'site', main_table
        nil
      else
        nil
      end
    end
    
    def context_relation(clause)
      fields = case clause
      when 'self'
        ['id', 'id']
      when 'parent'
        ['id', 'parent_id']
      when 'project'
        ['id', 'project_id']
      when 'site', main_table
        nil
      else
        nil
      end
      
      if fields
        "#{field_or_param(fields[0])} = #{field_or_param(fields[1], table(main_table,-1))}"
      else
        nil
      end
    end

    # Direct filter
    def direct_filter(rel)
      case rel
      when 'letters'
        "#{table}.kpath LIKE 'NNL%'"
      when 'clients'
        "#{table}.kpath LIKE 'NRCC%'"
      else
        nil
      end
    end
    
    # Return true if the clause is a direct filter (relation without a join).
    def direct_filter?(rel)
      rel == main_table ||
      rel == 'children' ||
      direct_filter(rel) != nil
    end

    # Filters that need a join
    def join_relation(rel)
      join = case rel
      when 'recipients'
        ['source_id', 4, 'target_id']
      when 'icons'
        ['target_id', 5, 'source_id']
      else
        nil
      end
      
      if join
        add_table('links')
        # source --> target
        "#{field_or_param('id')} = #{table('links')}.#{join[2]} AND #{table('links')}.relation_id = #{join[1]} AND #{table('links')}.#{join[0]} = #{field_or_param('id', table(main_table,-1))}"
      else
        nil
      end
    end
    
    # Overwrite this and take car to check for valid fields.
    def map_field(fld, table_name)
      if ['id', 'parent_id', 'project_id', 'section_id', 'kpath', 'name'].include?(fld)
        "#{table_name}.#{fld}"
      else
        # error, raise
      end
    end
end

class QueryTest < Test::Unit::TestCase
  yaml_dir File.dirname(__FILE__)
  yaml_test :basic, :joins, :filters
  
  def parse(value, opts)
    TestQuery.new(value).to_sql
  end
  
  make_tests
end