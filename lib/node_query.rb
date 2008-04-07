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
    direct_relation(txt) ||
    direct_filter(txt)   ||
    join_relation(txt)
  end
  
  # default relation filter is to search in the current node's children
  def default(clause)
    if direct_filter(clause)
      'parent'
    else
      nil
    end
  end
  
  def after_parse
    @filters << "\#{secure_scope('#{table_at(main_table,0)}')}"
  end
  
  private
    
    # Relations that can be resolved without a join
    def direct_relation(txt)
      case txt
      when 'site'
        nil
      when 'section'
        "#{table}.section_id = \#{#{@node_name}.get_section_id}"
      when 'project'
        "#{table}.project_id = \#{#{@node_name}.get_project_id}"
      when 'parent'
        "#{table}.parent_id = \#{#{@node_name}.id}"
      else
        nil
      end
    end

    # Direct filter
    def direct_filter(rel)
      case rel
      when main_table
        nil
      ######## special cases #######
      else  
        if klass = Node.get_class(rel)
          ######## class filters #######
          "#{table}.kpath LIKE '#{klass.kpath}%'"
        else
          # unknown class
          nil
        end
      end
    end

    # Filters that need a join
    def join_relation(txt)
      case txt
      when 'recipients'
        add_table('links')
        add_table(main_table)
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
    
    def map_field(field)
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
        if Node.zafu_readable?(key) && Node.column_names.include?(key)
          function ? "#{function}(#{key})" : key
        else
          # bad attribute
          nil
        end
      end
    end
end