require 'querybuilder'
# Since NodeQuery uses a special scope (secure_scope) that needs to be evaluated _in the query string_, you cannot
# use query.sql. You have to use: eval query.to_s. This is not an issue since normal useage for NodeQuery is to be
# compilated into an ERB template.
class NodeQuery < QueryBuilder
  attr_reader :context, :uses_node_name, :node_name
  set_main_table 'nodes'
  set_main_class 'Node'
  @@filter_fields = {'id' => {:key => 'zip'}}

  # TODO: should glob SITES_ROOT/**/custom_queries...
  load_custom_queries File.join(File.dirname(__FILE__), 'custom_queries')

  def self.insert_zero_link(link_class)
    return if link_class.find_by_id(0)
    link_class.connection.execute "INSERT INTO #{link_class.table_name} (id,target_id,source_id,status,comment) VALUES (0,0,0,NULL,NULL)"
    unless link_class.find_by_id(0)
      # the zero id is replaced by auto-increment value
      last_id = link_class.find(:first, :order => 'id DESC').id
      link_class.connection.execute "UPDATE #{link_class.table_name} SET id = 0 WHERE id = #{last_id}"
    end
  end

  def self.add_filter_field(key, fld_def)
    @@filter_fields[key] = fld_def
  end

  def initialize(query, opts = {})
    @uses_node_name = false
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

  def default_context_filter
    'self'
  end

  def after_parse
    @where.unshift "(\#{#{@node_name}.secure_scope('#{table}')})"
    if @tables.include?('links')
      link_table = table('links')
      @select << "#{link_table}.id AS link_id,#{Zena::Use::Relations::LINK_ATTRIBUTES.map {|l| "#{link_table}.#{l} AS l_#{l}"}.join(',')}"
    elsif @errors_unless_safe_links
      @errors += @errors_unless_safe_links
    end
    @distinct = true if @tables.include?('versions')
  end

  # Erb finder used by zafu
  def finder(count)
    return 'nil' unless valid?
    case count
    when :count
      "#{node_name}.do_find(:count, #{self.to_s(:count)}, #{!uses_node_name}, #{main_class})"
    else
      "#{node_name}.do_find(#{count.inspect}, #{self.to_s}, #{!uses_node_name}, #{main_class})"
    end
  end

  private
    # Make sure all alternate queries include "links.id = 0" (dummy link)
    def fix_where_list(where_list)
      return unless @tables.include?('links')
      where_list.each do |f|
        unless f =~ /links\./
          f << " AND links.id = 0"
        end
      end
      true
    end

    # Used to resolve 'in' clauses ('in project', 'in parent', etc)
    def context_filter_fields(rel, is_last = false)
      case rel
      when 'self'
        ['parent_id', 'id']
      when 'parent'
        is_last ? ['parent_id', 'parent_id'] : ['parent_id', 'id']
      when 'project'
        is_last ? ['project_id', 'project_id'] : ['project_id', 'id']
      when 'section'
        is_last ? ['section_id', 'section_id'] : ['section_id', 'id']
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
      when 'parent', 'project', 'section'
        fields = ['id', "#{rel}_id"]
      when 'parents', 'projects', 'sections'
        if @table_counter[main_table] > 0 || @tables.include?('links')
          fields = ['id', "#{rel[0..-2]}_id"]
        end
      when 'root'
        @where << "#{table}.id = #{current_site.root_id}"
        return true
      when 'author', 'traductions', 'versions'
        # TODO: not implemented yet...
        return nil
      when 'visitor'
        @where << "#{table}.id = #{insert_bind("visitor.contact_id")}"
        return true
      end

      unless fields
        if klass = Node.get_class(rel)
          parse_context(default_context_filter) unless context
          @where << "#{table}.kpath LIKE '#{klass.kpath}%'"
          return true
        else
          # unknown class
          return nil
        end
      end

      @where << "#{field_or_attr(fields[0])} = #{field_or_attr(fields[1], table(main_table,-1))}"
      true
    end

    def parse_change_class(rel, is_last)
      case rel
      when 'comment', 'comments'
        if is_last
          # no need to load discussions, versions and all the mess
          add_table('comments')
          @where << "#{table('comments')}.discussion_id = #{map_attr('discussion_id')}"
          return CommentQuery # class change
        else
          # parse_context(default_context_filter, true) if is_last
          # after_parse
          add_table('discussions')
          add_table('comments')
          @where << "#{table('discussions')}.node_id = #{table('nodes')}.id"
          @where << "#{table('comments')}.discussion_id = #{table('discussions')}.id"
          after_parse
          return CommentQuery
        end
      else
        return nil
      end
    end

    # Filters that need a join
    def join_relation(rel, context, new_table_alias = nil, previous_table_alias = nil)
      new_table_alias      ||= table(main_table)
      previous_table_alias ||= table(main_table, -1)

      if rel == main_table || rel == 'children'
        # dummy clauses
        parse_context(default_context_filter) unless context
        return :void
      end

      if rel = RelationProxy.find_by_role(rel.singularize)
        # We cannot use a LEFT JOIN here because it will totally mess up if we merge alternate queries
        add_table('links')
        # (= other_side = result) target <-- source (= link_side = caller)
        if context && context != 'self'
          # tagged in project (not equal to 'tagged from nodes in project')
          # remove caller join
          @distinct = true
          @where << "#{field_or_attr('id', new_table_alias)} = #{table('links')}.#{rel.other_side} AND #{table('links')}.relation_id = #{rel[:id]}"
        else
          @where << "#{field_or_attr('id', new_table_alias)} = #{table('links')}.#{rel.other_side} AND #{table('links')}.relation_id = #{rel[:id]} AND #{table('links')}.#{rel.link_side} = #{field_or_attr('id', previous_table_alias)}"
        end
      else
        nil
      end
    end

    def map_literal(value, env = :sql)
      if value =~ /(.*?)\[(visitor|param):(\w+)\](.*)/
        val_start = $1 == '' ? '' : "#{$1.inspect} +"
        val_end   = $4 == '' ? '' : "+ #{$4.inspect}"
        case $2
        when 'visitor'
          value = env == :sql ? insert_bind("#{val_start}Node.zafu_attribute(visitor.contact, #{$3.inspect})#{val_end}") : nil
        when 'param'
          value = env == :sql ? insert_bind("#{val_start}params[:#{$3}].to_s#{val_end}") : "params[:#{$3}]"
        end
      else
        value = env == :sql ? quote(value) : nil
      end
    end

    # Translate fields used for query/sort/grouping (context parameter) into something useable by SQL. Add the appropriate tables when needed.
    def map_field(field, table_name = table, context = nil)
      return map_literal("[#{field}]") if field =~ /\Aparam:/
      case field[0..1]
      when 'd_'
        # DYNAMIC ATTRIBUTE
        key = field[2..-1]
        key, function = parse_sql_function_in_field(key)
        key = Zena::Db.sql_function(function, dyn_value('versions', key, context))
      when 'c_'
        # CONTENT TABLE
        field = field[2..-1]
        # FIXME: implement #41
        nil
      when 'v_'
        # VERSION
        key = field[2..-1]
        key, function = parse_sql_function_in_field(key)
        if Version.attr_public?(key) && Version.column_names.include?(key)
          vtable_name = needs_table('nodes', 'versions', "TABLE1.id = TABLE2.node_id")
          Zena::Db.sql_function(function, "#{vtable_name}.#{key}")
        else
          # bad version attribute
          nil
        end
      when 'l_'
        key, function = parse_sql_function_in_field(field)
        if key == 'l_status' || key == 'l_comment' || key == 'l_date' || (key == 'l_id' && [:order, :group].include?(context))
          @errors_unless_safe_links ||= []
          @errors_unless_safe_links << "cannot use link field '#{key}' in this query" unless (key == 'l_id' && context == :order)
          # ok
          Zena::Db.sql_function(function, "#{table('links')}.#{key[2..-1]}")
        else
          # bad attribute
          nil
        end
      else
        # NODE
        key, function = parse_sql_function_in_field(field)
        if context == :filter
          if map_def = @@filter_fields[key]
            if table_def = map_def[:table]
              table_to_use = needs_table(*table_def)
            else
              table_to_use = table_name
            end
            Zena::Db.sql_function(function, "#{table_to_use}.#{map_def[:key]}")
          elsif (Node.attr_public?(key) && Node.column_names.include?(key))
            Zena::Db.sql_function(function, "#{table_name}.#{key}")
          elsif key =~ /^(.*)_ids?$/
            # tag_id = 33  ===> join links as lk, nodes as tt .......
            rel = $1

            if RelationProxy.find_by_role(rel.singularize)
              add_table('jnode', 'nodes')
              join_relation(rel, nil, table('jnode'), table('nodes'))
              "#{table('jnode')}.zip"
            else
              nil
            end
          else
            nil
          end
        else
          if ['id', 'parent_id','project_id','section_id'].include?(key) || (Node.attr_public?(key) && Node.column_names.include?(key))
            Zena::Db.sql_function(function, "#{table_name}.#{key}")
          else
            # bad attribute
            nil
          end
        end
      end
    end

    def valid_field?(table_name, fld)
      # FIXME: security !
      true
    end

    def map_attr(fld, env = :sql)
      case fld
      when 'project_id', 'section_id', 'discussion_id'
        @uses_node_name = true
        insert_bind("#{@node_name}.get_#{fld}")
      when 'id', 'parent_id'
        @uses_node_name = true
        insert_bind("#{@node_name}.#{fld}")
      else
        # Node.attr_public?(fld)
        # bad parameter
        @errors << "invalid parameter '#{fld}'"
        "0"
      end
    end

    def parse_paginate_clause(paginate)
      return @offset unless paginate
      if !@limit
        # TODO: raise error ?
        @errors << "invalid paginate clause '#{paginate}' (used without limit)"
        nil
      elsif (fld = map_literal("[param:#{paginate}]", :ruby)) && (page_size = @limit[/ LIMIT (\d+)/,1])
        @page_size = [2,page_size.to_i].max
        " OFFSET #{insert_bind("((#{fld}.to_i > 0 ? #{fld}.to_i : 1)-1)*#{page_size.to_i}")}"
      else
        @errors << "invalid paginate clause '#{paginate}'"
        nil
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
        all_ok = true
        filter = f.gsub(/TABLE_NAME(\[(\w+)\]|)/) do
          if $2
            if @table_counter[$2]
              table($2)
            else
              all_ok = false
              @errors << "invalid table_name '#{$2}' in raw filter"
              @errors.uniq!
            end
          else
            table
          end
        end
        @where << filter if all_ok
      end
    end

    def dyn_value(table_name, key, context)
      @dyn_keys[table_name] ||= {}
      @dyn_keys[table_name][key] ||= begin
        needs_table('nodes', 'versions', "TABLE1.id = TABLE2.node_id")
        dtable = needs_join_table('versions', 'LEFT', 'dyn_attributes', "TABLE1.id = TABLE2.owner_id AND TABLE2.key = #{quote(key)}", "versions=dyn_attributes=#{key}")
        "#{dtable}.value"
      end
    end

    def parse_custom_query_argument(key, value)
      return nil unless value
      super.gsub(/(RELATION_ID|NODE_ATTR)\(([^)]+)\)/) do
        type, value = $1, $2
        if type == 'RELATION_ID'
          role = value
          if rel = RelationProxy.find_by_role(role.singularize)
            rel[:id]
          else
            @errors << "could not find Relation '#{role}' in custom query"
            '-1'
          end
        elsif type == 'NODE_ATTR'
          attribute = value
          if Node.attr_public?(attribute)
            insert_bind("#{@node_name}.#{attribute}")
          else
            @errors << "cannot read attribute '#{attribute}' in custom query"
            '-1'
          end
        end
      end.gsub(/NODE_ID/) do
        @uses_node_name = true
        insert_bind("#{@node_name}.id")
      end
    end

    def extract_custom_query(list)
      super.singularize
    end

    def quote(literal)
      Node.connection.quote(literal)
    end
end

module Zena
  module Use
    module NodeQueryFinders
      module AddUseNodeQueryMethod
        def self.included(base)
          # create class methods
          base.extend AddUseNodeQueryMethodImpl
        end
      end

      module AddUseNodeQueryMethodImpl
        def use_node_query
          class_eval do
            include Zena::Use::NodeQueryFinders::InstanceMethods
            class << self
              include Zena::Use::NodeQueryFinders::ClassMethods
            end
          end
        end
      end

      module ClassMethods

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
        #def build_find(count, pseudo_sql, node_name, raw_filters = nil, ignore_warnings = false, ref_date = nil)
        def build_find(count, pseudo_sql, opts = {})
          if count == :first
            opts[:limit] = 1
          end
          NodeQuery.new(pseudo_sql, opts.merge(:custom_query_group => visitor.site.host))
        end
      end # ClassMethods


      module InstanceMethods

        # Find a node and propagate visitor
        def do_find(count, query, ignore_source = false, klass = Node)
          return nil if query.empty?
          return nil if (new_record? && !ignore_source) # do not run query (might contain nil id)

          case count
          when :all
            res = klass.find_by_sql(query)
            if res == []
              nil
            else
              res.each {|r| visitor.visit(r)}
              res
            end
          when :first
            res = klass.find_by_sql(query).first
            visitor.visit(res) if res
            res
          when :count
            klass.count_by_sql(query)
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
            query = Node.build_find(count, rel, :node_name => 'self')
            if query.valid?
              do_find(count, eval(query.to_s))
            else
              nil
            end
          end
        end
      end # InstanceMethods
    end # NodeQueryFinders
  end # Use
end # Zena