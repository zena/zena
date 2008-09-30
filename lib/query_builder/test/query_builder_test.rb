require File.join(File.dirname(__FILE__) , '..', '..', 'yaml_test.rb')
require File.join(File.dirname(__FILE__) , '..', 'lib', 'query_builder')
require 'ruby-debug'
Debugger.start

class TestQuery < QueryBuilder
  set_main_table 'objects'
  set_main_class 'Object'
  
  load_custom_queries File.join(File.dirname(__FILE__), 'custom_queries')
  
  # Build joins and filters from a relation.
  def parse_relation(rel, context)
    unless context_relation(rel, context) || direct_filter(rel, context) || join_relation(rel, context)
      @errors << "unknown relation '#{rel}'"
    end
  end
  
  # default context filter is to search in the current node's children (in self)
  def default_context_filter
    'self'
  end
  
  private
    
    # Root filters (relations that can be solved without a join). Think 'in clause' (in self, in parent).
    def context_filter_fields(clause, is_last = false)
      case clause
      when 'self'
        ['parent_id', 'id']
      when 'parent'
        is_last ? ['parent_id', 'parent_id'] : ['parent_id', 'id']
      when 'project'
        is_last ? ['project_id', 'project_id'] : ['project_id', 'id']
      when 'site', main_table
        :void
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
      
      @where << "#{field_or_attr(fields[0])} = #{field_or_attr(fields[1], table(main_table,-1))}"
    end

    # Direct filter
    def direct_filter(rel, context)
      case rel
      when 'letters'
        parse_context(default_context_filter) unless context
        @where << "#{table}.kpath LIKE 'NNL%'"
      when 'clients'
        parse_context(default_context_filter) unless context
        @where << "#{table}.kpath LIKE 'NRCC%'"
      else
        return false
      end
    end

    def parse_change_class(rel, is_last)
      case rel
      when 'users'
        parse_context(default_context_filter, true) if is_last
        add_table('users')
        @where << "#{table('users')}.node_id = #{field_or_attr('id')}"
        return TestUserQuery # class change
      else
        return nil
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
      @where << "#{field_or_attr('id')} = #{table('links')}.#{fields[2]} AND #{table('links')}.relation_id = #{fields[1]} AND #{table('links')}.#{fields[0]} = #{field_or_attr('id', table(main_table,-1))}"
    end
    
    # Overwrite this and take car to check for valid fields.
    def map_field(fld, table_name, is_null = false)
      if ['id', 'parent_id', 'project_id', 'section_id', 'kpath', 'name', 'event_at', 'custom_a'].include?(fld)
        "#{table_name}.#{fld}"
      else
        # error, raise
      end
    end
end

class TestUser
end

class TestUserQuery < QueryBuilder
  set_main_table 'users'
  set_main_class 'TestUser'
  
  # Default sort order
  def default_order_clause
    "name ASC, first_name ASC"
  end
  
  def default_context_filter
    'self'
  end
  
  def parse_change_class(rel, is_last)
    case rel
    when 'objects'
      parse_context(default_context_filter, true) if is_last
      add_table('objects')
      @where << "#{table('objects')}.id = #{field_or_attr('node_id')}"
      return TestUserQuery # class change
    else
      return nil
    end
  end
  
  def parse_relation(clause, context)
    return nil
  end
  
  def context_filter_fields(clause, is_last = false)
    nil
  end
  
  def parse_context(clause, is_last = false)
    
    if fields = context_filter_fields(clause, is_last)
      @where << "#{field_or_attr(fields[0])} = #{field_or_attr(fields[1], table(main_table,-1))}" if fields != :void
    else
      @errors << "invalid context '#{clause}'"
    end
  end
  
  # Map a litteral value to be used inside a query
  def map_literal(value)
    value.inspect
  end
  
  
  # Overwrite this and take car to check for valid fields.
  def map_field(fld, table_name, context = nil)
    if ['id', 'name', 'first_name', 'node_id'].include?(fld)
      "#{table_name}.#{fld}"
    else
      # TODO: error, raise / ignore ?
    end
  end
  
  def map_attr(fld)
    fld.to_s.upcase
  end
end

class QueryTest < Test::Unit::TestCase
  yaml_test
  
  def parse(key, source, opts)
    query = TestQuery.new(source, opts)
    
    case key
    when 'res'
      (query.main_class != Object ? "#{query.main_class.to_s}: " : '') + if res = query.to_sql
        res
      else
        query.errors.join(", ")
      end
    when 'count'
      query.count_sql
    else
      "parse not implemented for '#{key}' in query_builder_test.rb"
    end
  end
  
  make_tests
end