require File.join(File.dirname(__FILE__) , 'query_builder', 'lib', 'query_builder')

class NodeQuery < QueryBuilder
  attr_reader :context
  set_main_table :nodes
  
  def initialize(query, context = {})
    @table_name = 'nodes'
    @context    = context
    @node_name  = context[:node_name]
    super(query)
  end
  
  # Build joins and filters from a relation.
  def relation(txt)
    context_filter(txt) ||
    direct_filter(txt)  ||
    join_relation(txt)
  end
  
  # default relation filter is to search in the current node's children
  def default(clause)
    if clause == main_table || direct_filter(clause)
      'self'
    else
      nil
    end
  end
  
  def after_parse
    @filters.unshift "\#{secure_scope('#{table}')}"
  end
  
  private
    def context_clause?(clause)
      ['self', 'children', 'parent', 'project', 'section', 'site', main_table].include?(clause)
    end
    
    # Relations that can be resolved without a join
    def context_filter_fields(txt)
      case txt
      when 'self', 'children'
        ['parent_id', 'id']
      when 'parent'
        ['parent_id', 'parent_id']
      when 'project'
        ['project_id', 'project_id']
      when 'section'
        ['section_id', 'section_id']
      when 'site', main_table
        nil
      else
        nil
      end
    end
    
    #def context_filter(clause)
    #  if fields = context_filter_fields(clause)
    #    "#{field_or_param(fields[0])} = #{field_or_param(fields[1], table(main_table,-1))}"
    #  else
    #    nil
    #  end
    #end
    
    # Direct filter
    def direct_filter(rel)
      if rel == main_table
        nil
      elsif klass = Node.get_class(rel)
        ######## class filters #######
        "#{table}.kpath LIKE '#{klass.kpath}%'"
      else
        # unknown class
        nil
      end
    end

    # Filters that need a join
    def join_relation(txt)
      case txt
      when 'recipients'
        add_table('links')
        "#{table('links')}.relation_id = 4 AND #{table('links')}.source_id = #{table(main_table,-1)}.id AND #{table('links')}.target_id = #{table}.id"
      else
        nil
      end
    end
    
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
    
    def map_field(field, table_name = table)
      case field[0..1]
      when 'd_'
        # DYNAMIC ATTRIBUTE
        key = field[2..-1]
        key, function = parse_sql_function_in_field(key)
  
        unless dyn_keys[key]
          dyn_counter += 1
          unless has_version_join
            joins << version_join
            has_version_join = true
          end
          joins << "LEFT JOIN dyn_attributes AS da#{dyn_counter} ON da#{dyn_counter}.owner_id = vs.id AND da#{dyn_counter}.key = '#{key}'"
          dyn_keys[key] = "da#{dyn_counter}.value"
        end
        key = function ? "#{function}(#{dyn_keys[key]})" : dyn_keys[key]
      when 'c_'
        # CONTENT TABLE
        field = field[2..-1]
        # FIXME: implement #41
        nil
      when 'v_'
        # VERSION
        key = field[2..-1]
        key, function = parse_sql_function_in_field(key)
        if Version.zafu_readable?(key) && Version.column_names.include?(key)
          unless has_version_join
            joins << version_join
            has_version_join = true
          end
    
          key = function ? "#{function}(vs.#{key})" : "vs.#{key}"
        else
          # bad version attribute
          nil
        end
      else
        # NODE
        key, function = parse_sql_function_in_field(field)
        if ['id','parent_id','project_id','section_id'].include?(key) || (Node.zafu_readable?(key) && Node.column_names.include?(key))
          function ? "#{function}(#{table_name}.#{key})" : "#{table_name}.#{key}"
        else
          # bad attribute
          nil
        end
      end
    end
    
    def valid_field?(table_name, fld)
      true
    end
    
    def map_parameter(fld)
      case fld
      when 'project_id', 'section_id'
        "\#{#{@node_name}.get_#{fld}}"
      when 'id', 'parent_id'
        "\#{#{@node_name}.#{fld}}"
      else
        # Node.zafu_readable?(fld)
        # bad parameter
      end
    end
    
    
    # When a field is defined as log_at:year, return [log_at, year].
    def parse_sql_function_in_field(field)
      if field =~ /\A(\w+):(\w+)\Z/
        if ['year'].include?($2)
          [$1,$2]
        else
          [$1]
        end
      else
        [field]
      end
    end
end