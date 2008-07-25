require File.join(File.dirname(__FILE__) , 'query_builder', 'lib', 'query_builder')

class CommentQuery < QueryBuilder
  attr_reader :uses_node_name
  set_main_table 'comments'
  set_main_class 'Comment'
  
  # Default sort order
  def default_order_clause
    "created_at ASC"
  end
  
  def default_context_filter
    # should never be called alone
    raise Exception.new("CommentQuery should only be called from within NodeQuery")
  end
  
  def parse_change_class(rel, is_last)
    case rel
    when 'author'
      add_table('users')
      @where << "#{table('users')}.id = #{field_or_param('user_id')}"
      # should we only move to Users ?
      add_table('nodes')
      @where << "#{table('nodes')}.id = #{field_or_param('users','contact_id')}"
      return NodeQuery # class change
    else
      return nil
    end
  end
  
  # Map a litteral value to be used inside a query
  def map_literal(value)
    if value =~ /(.*?)\[(visitor|param):(\w+)\](.*)/
      val_start = $1 == '' ? '' : "#{$1.inspect} +"
      val_end   = $4 == '' ? '' : "+ #{$4.inspect}"
      case $2
      when 'visitor'
        value = "\#{Node.connection.quote(\#{#{val_start}Node.zafu_attribute(visitor.contact, #{$3.inspect})#{val_end}})}"
      when 'param'
        value = "\#{Node.connection.quote(#{val_start}params[:#{$3}].to_s#{val_end})}"
      end
    else
      value = Node.connection.quote(value)
    end
  end
  
  # Overwrite this and take car to check for valid fields.
  def map_field(fld, table_name, context = nil)
    if ['status', 'updated_at', 'author_name', 'created_at', 'title', 'text', 'user_id'].include?(fld)
      "#{table_name}.#{fld}"
    else
      # TODO: error, raise / ignore ?
    end
  end
  
  def map_parameter(fld)
    # error
    nil
  end
end
