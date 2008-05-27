require File.join(File.dirname(__FILE__) , 'query_builder', 'lib', 'query_builder')

class NodeQuery < QueryBuilder
  attr_reader :context
  set_main_table :nodes
  
  def initialize(query, opts = {})
    @table_name = 'nodes'
    @node_name  = opts[:node_name]
    # list of dyna_attributes keys allready in the filter
    @dyn_keys   = {}
    
    super(query, opts)
    # Raw filters are statements prepared that should not be further processed except for table_name replacement.
    parse_raw_filters(opts[:raw_filters])
  end
  
  # Build joins and filters from a relation.
  def parse_relation(rel, context)
    # join_relation first so we can overwrite 'class' finders (images) with a relation.
    unless join_relation(rel, context) || context_relation(rel, context)
      @errors << "unknown relation '#{rel}'"
    end
  end
  
  # Default sort order
  def default_order_clause
    "position ASC, name ASC"
  end
  
  def after_parse
    @filters.unshift "(\#{#{@node_name}.secure_scope('#{table}')})"
    if @tables.include?('links') && safe_links_attributes?
      @select << "#{table('links')}.id AS link_id, links.status AS l_status, links.comment AS l_comment"
    elsif @errors_unless_safe_links
      @errors += @errors_unless_safe_links
    end
    @distinct = true if @tables.include?('versions')
  end
  
  private
    def safe_links_attributes?
      (@alt_filters || []).each do |f|
        unless f =~ /links\./
          return false
        end
      end
      true
    end
    
    # Used to resolve 'in' clauses ('in project', 'in parent', etc)
    def context_filter_fields(rel, as_sub = false)
      case rel
      when 'self'
        ['parent_id', 'id']
      when 'parent'
        as_sub ? ['parent_id', 'id'] : ['parent_id', 'parent_id']
      when 'project'
        as_sub ? ['project_id', 'id'] : ['project_id', 'project_id']
      when 'section'
        as_sub ? ['section_id', 'id'] : ['section_id', 'section_id']
      when 'site', main_table
        :void
      else
        nil
      end
    end
    
    # Relations that can be resolved without a join
    def context_relation(rel, context)
      case rel
      when 'self'
        fields = ['id', 'id']
      when 'parent'
        fields = ['id', 'parent_id']
      when 'project'
        fields = ['id', 'project_id']
      when 'section'
        fields = ['id', 'section_id']
      when 'root'
        @filters << "#{table}.id = #{current_site.root_id}"
        return true
      when 'author', 'traductions', 'versions'
        # TODO: not implemented yet...
        return nil
      when 'visitor'
        @filters << "#{table}.id = \#{visitor.contact_id}"
        return true
      else
        if klass = Node.get_class(rel)
          parse_context('self') unless context
          @filters << "#{table}.kpath LIKE '#{klass.kpath}%'"
          return true
        else
          # unknown class
          return nil
        end
      end
      
      @filters << "#{field_or_param(fields[0])} = #{field_or_param(fields[1], table(main_table,-1))}"
      true
    end
    
    # Filters that need a join
    def join_relation(rel, context)
      if rel == main_table || rel == 'children'
        # dummy clauses
        parse_context('self') unless context
        return :void
      end
      
      if rel = Relation.find_by_role(rel.singularize)
        # We cannot use a LEFT JOIN here because it will totally mess up if we merge alternate queries
        add_table('links')
        # (= other_side = result) target <-- source (= link_side = caller)
        if context && context != 'self'
          # tagged in project (not equal to 'tagged from nodes in project')
          # remove caller join
          @distinct = true
          @filters << "#{field_or_param('id')} = #{table('links')}.#{rel.other_side} AND #{table('links')}.relation_id = #{rel[:id]}"
        else
          @filters << "#{field_or_param('id')} = #{table('links')}.#{rel.other_side} AND #{table('links')}.relation_id = #{rel[:id]} AND #{table('links')}.#{rel.link_side} = #{field_or_param('id', table(main_table,-1))}"
        end
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
    
    def map_field(field, table_name = table, context = nil)
      case field[0..1]
      when 'd_'
        # DYNAMIC ATTRIBUTE
        key = field[2..-1]
        key, function = parse_sql_function_in_field(key)
        key = function ? "#{function}(#{dyn_value('versions', key, context)})" : dyn_value('versions', key, context)
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
          vtable_name = needs_table('nodes', 'versions', "TABLE1.id = TABLE2.node_id")
          key = function ? "#{function}(#{vtable_name}.#{key})" : "#{vtable_name}.#{key}"
        else
          # bad version attribute
          nil
        end
      when 'l_'  
        key, function = parse_sql_function_in_field(field)
        if key == 'l_status' || key == 'l_comment'
          @errors_unless_safe_links ||= []
          @errors_unless_safe_links << "cannot use link field '#{key}' in this query"
          # ok
          function ? "#{function}(#{table('links')}.#{key[2..-1]})" : "#{table('links')}.#{key[2..-1]}"
        else
          # bad attribute
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
      # FIXME: security !
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
    
    def parse_raw_filters(filters)
      return unless filters
      filters.each do |f|
        @filters << f.gsub("TABLE_NAME", table)
      end
    end
    
    def dyn_value(table_name, key, context)
      @dyn_keys[table_name] ||= {}
      @dyn_keys[table_name][key] ||= begin
        needs_table('nodes', 'versions', "TABLE1.id = TABLE2.node_id")
        dtable = needs_join_table('versions', 'LEFT', 'dyn_attributes', "TABLE1.id = TABLE2.owner_id AND TABLE2.key = '#{key.gsub(/[^a-z_A-Z]/,'')}'", "versions=dyn_attributes=#{key}")
        "#{dtable}.value"
      end
    end
end


module Zena
  module Query
    module UseNodeQuery
      # this is called when the module is included into the 'base' module
      def self.included(base)
        # add all methods from the module "AddActsAsMethod" to the 'base' module
        base.extend Zena::Query::ClassMethods
      end
    end
    
    module ClassMethods
      def use_node_query
        class_eval <<-END
        include Zena::Query::InstanceMethods
        END
      end
      
      # Return an sql query string that will be used by 'do_find':
      # build_find(:all, PSEUDO_SQL, node_name) => "SELECT * FROM nodes WHERE nodes.parent_id = #{@node[:id]} AND ..."
      # PSEUDO_SQL: what to find in pseudo sql (See NodeQuery for details).
      # node_name: contextual variable name
      #
      # Pseudo sql syntax:
      #
      # '[CLASS|VCLASS|RELATION] [in [site|section|project|parent]|] [where CLAUSE|] [from SUB_QUERY|] or [PSEUDO_SQL]'
      #
      # with :
      #   * CLASS:  a native class ('images', 'documents', 'pages', 'projects', ...)
      #   * VCLASS: a virtual class created by the user ('posts', 'houses', ...)
      #   * RELATION: a relation defined by the user ('icon_for', 'news', 'calendar', ...)
      #   * CLAUSE: field = value ('log_at:year = 2005'). You can use parameters, visitor data in clause: 'log_at:year = [param:year]', 'd_assigned = [visitor:name]'. You can only use 'and' in clauses. 'or' is not supported. You can use version and/or dynamic attributes : 'v_comment = super', 'd_priority = low'.
      #
      # Examples: 'todos in section where d_priority = high and d_assigned = [visitor:name]'
      def build_find(count, pseudo_sql, node_name, raw_filters = nil, ignore_warnings = false)
        if count != :all
          limit = 1
        end
        query = NodeQuery.new(pseudo_sql, :node_name => node_name, :limit => limit, :raw_filters => raw_filters, :ignore_warnings => ignore_warnings)
        [query.to_sql, query.errors]
      end
    end
    

    module InstanceMethods
      def do_find(count, query, ignore_source = false)
        return nil if query.empty?
        return nil if new_record? && !ignore_source
        res = Node.find_by_sql(query)
        if count == :all
          if res == []
            nil
          else
            res.each{|r| visitor.visit(r)}
            res
          end
        elsif res = res.first
          visitor.visit(res)
          res
        else
          nil
        end
      end
      
      # Find related nodes.
      # See Node#build_find for details on the options available.
      def find(count, rel)
        rel = [rel] if rel.kind_of?(String)
        
        if rel.size == 1 && self.class.zafu_known_contexts[rel.first]
          self.send(rel.first)
        else
          sql, errors = Node.build_find(count, rel, 'self')
          if sql
            do_find(count, eval("\"#{sql}\""))
          else
            nil
          end
        end
      end
    end
  end
end

ActiveRecord::Base.send :include, Zena::Query::UseNodeQuery