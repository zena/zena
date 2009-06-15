
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
  
  # Overwrite this and take car to check for valid fields.
  def map_field(fld, table_name, context = nil)
    if ['id', 'name', 'first_name', 'node_id'].include?(fld)
      "#{table_name}.#{fld}"
    else
      # TODO: error, raise / ignore ?
    end
  end
end