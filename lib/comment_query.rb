require File.join(File.dirname(__FILE__) , 'query_builder', 'lib', 'query_builder')

class CommentQuery < QueryBuilder
  attr_reader :uses_node_name, :node_name
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
      @where << "#{table('users')}.id = #{field_or_attr('author_id')}"
      # should we move on to Contact ?
    when 'node', 'nodes'
      add_table('discussions')
      add_table('nodes')
      @where << "#{table('discussions')}.id = #{table('comments')}.discussion_id"
      @where << "#{table('nodes')}.id = #{table('discussions')}.node_id"
      return NodeQuery # class change
    else
      return nil
    end
  end
  
  # Same as NodeQuery... DRY needed.
  def map_literal(value)
    if value =~ /(.*?)\[(node|visitor|param):(\w+)\](.*)/
      val_start = $1 == '' ? '' : "#{$1.inspect} +"
      val_end   = $4 == '' ? '' : "+ #{$4.inspect}"
      case $2
      when 'visitor'
        if $3 == 'user_id'
          value = "visitor.id"
        else
          value = "Node.zafu_attribute(visitor.contact, #{$3.inspect})"
        end
      when 'node'
        @uses_node_name = true
        if $3 == 'user_id'
          value = "#{@node_name}.user_id"
        else
          value = "Node.zafu_attribute(#{@node_name}, #{$3.inspect})"
        end
      when 'param'
        return "\#{Node.connection.quote(#{val_start}params[:#{$3}].to_s#{val_end})}"
      end
      
      if !val_start.blank? || !val_end.blank?
        "\#{Node.connection.quote(#{val_start}#{value}#{val_end})}"
      else
        "\#{#{value}}"
      end
    else
      value = Node.connection.quote(value)
    end
  end
  
  # Overwrite this and take car to check for valid fields.
  def map_field(fld, table_name, context = nil)
    if ['status', 'updated_at', 'author_name', 'created_at', 'title', 'text', 'author_id'].include?(fld)
      "#{table_name}.#{fld}"
    else
      # TODO: error, raise / ignore ?
    end
  end
  
  def map_attr(fld)
    # error
    nil
  end
  
  # Erb finder used by zafu
  def finder(count)
    return 'nil' unless valid?
    case count
    when :count
      "#{node_name}.do_find(:count, \"#{count_sql}\", #{!uses_node_name}, #{main_class})"
    else
      "#{node_name}.do_find(#{count.inspect}, \"#{to_sql}\", #{!uses_node_name}, #{main_class})"
    end
  end
end
