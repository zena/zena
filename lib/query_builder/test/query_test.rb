require File.join(File.dirname(__FILE__) , '..', '..', 'yaml_test.rb')
require File.join(File.dirname(__FILE__) , '..', 'lib', 'query_builder')
require 'ruby-debug'
Debugger.start

class TestQuery < QueryBuilder
  
  # Build joins and filters from a relation.
  def parse_relation(rel, context)
    unless context_relation(rel, context) || direct_filter(rel, context) || join_relation(rel, context)
      @errors << "Unknown relation '#{rel}'."
    end
  end
  
  # default context filter is to search in the current node's children (in self)
  def default_context_filter
    'self'
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
    
    def context_relation(clause, context)
      case clause
      when 'self'
        fields = ['id', 'id']
      when 'parent'
        fields = ['id', 'parent_id']
      when 'project'
        fields = ['id', 'project_id']
      when main_table, 'children'
        parse_context(default_context_filter) unless context
        return true # dummy clause: does nothing
      else
        return false
      end
      
      @filters << "#{field_or_param(fields[0])} = #{field_or_param(fields[1], table(main_table,-1))}"
    end

    # Direct filter
    def direct_filter(rel, context)
      case rel
      when 'letters'
        parse_context(default_context_filter) unless context
        @filters << "#{table}.kpath LIKE 'NNL%'"
      when 'clients'
        parse_context(default_context_filter) unless context
        @filters << "#{table}.kpath LIKE 'NRCC%'"
      else
        return false
      end
    end

    # Filters that need a join
    def join_relation(rel, context)
      case rel
      when 'recipients'
        fields = ['source_id', 4, 'target_id']
      when 'icons'
        fields = ['target_id', 5, 'source_id']
      when 'tags'
        # just to test joins
        needs_join_table('objects', 'INNER', 'tags', 'TABLE1.id = TABLE2.node_id')
        return true
      else
        return false
      end
      
      add_table('links')
      # source --> target
      @filters << "#{field_or_param('id')} = #{table('links')}.#{fields[2]} AND #{table('links')}.relation_id = #{fields[1]} AND #{table('links')}.#{fields[0]} = #{field_or_param('id', table(main_table,-1))}"
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
    query = TestQuery.new(value)
    if res = query.to_sql
      return res
    else
      return query.errors.join(", ")
    end
  end
  
  make_tests
end