module Zafu
  module Context
    # TODO: test, rename ?
    def r_search_results
      pagination_key = 'page'
      out "<% set_#{pagination_key}_nodes = @search_count; set_#{pagination_key}_count = (set_#{pagination_key}_nodes / @search_per_page).ceil; set_#{pagination_key} = [1,params[:page].to_i].max -%>"
      @context[:vars] ||= []
      @context[:vars] << "#{pagination_key}_nodes"
      @context[:vars] << "#{pagination_key}_count"
      @context[:vars] << pagination_key
      @context[:paginate] = pagination_key
      do_list('@nodes')
    end

    # FIXME: replace by rubyless declarations
    def r_comments_to_publish
      open_context(:method => 'visitor.comments_to_publish', :class => [Comment])
    end

    def r_to_publish
      open_context(:method => 'visitor.to_publish', :class => [Version])
    end

    def r_proposed
      open_context(:method => 'visitor.proposed', :class => [Version])
    end

    def r_redactions
      open_context(:method => 'visitor.redactions', :class => [Version])
    end

    protected

      # FIXME: we should replace this with @context.find_context(finder) and move it into Zafu core.
      def change_context(rel, opts = {})
        # FIXME: replace with RubyLess.translate(rel)
        raw_filters = opts[:raw_filters] || []

        signature = [rel]
        unless params.empty?
          signature += [Hash[*params.map{|k,v| [k,String]}.flatten]]
        end

        if !opts[:skip_rubyless] && context = RubyLess::SafeClass.safe_method_type_for(node_class, signature)
          if params.empty?
            return context.merge(:method => "#{node}.#{context[:method]}")
          else
            return context.merge(:method => "#{node}.#{context[:method]}(#{params.inspect})")
          end
        end

        rel ||= 'self'

        # TODO: simplify !
        count   = opts[:find] || (['first','all','count'].include?(@params[:find]) ? @params[:find].to_sym : nil)

        # count ||= Node.plural_relation?(method) ? :all : :first
        unless count
          if params[:paginate] || child['each'] || child['group'] || Node.plural_relation?(rel)
            count = :all
          else
            count = :first
          end
        end


        if (count == :first)
          if rel == 'self'
            return {:method => node, :class => node_class}
          elsif rel == 'main'
            return {:method => '@node', :class => Node}
          elsif rel == 'root'
            return {:method => "(secure(Node) { Node.find(#{current_site[:root_id]})})", :class => Node}
          elsif rel == 'start'
            return {:method => 'start_node', :class => Node}
          elsif rel == 'visitor'
            return {:method => 'visitor.contact', :class => Contact}
          elsif rel =~ /^\d+$/
            return {:method => "(secure(Node) { Node.find_by_zip(#{rel.inspect})})", :class => Node}
          elsif node_name = find_stored(Node, rel)
            return {:method => node_name, :class => Node}
          elsif rel[0..0] == '/'
            rel = rel[1..-1]
            return {:method => "(secure(Node) { Node.find_by_path(#{rel.inspect})})", :class => Node}
          end
        end

        pseudo_sql, add_raw_filters = make_pseudo_sql(rel, params)
        raw_filters += add_raw_filters if add_raw_filters

        # FIXME: stored should be clarified and managed in a single way through links and contexts.
        # <r:void store='foo'>...
        # <r:link href='foo'/>
        # <r:pages from='foo'/> <-- this is just a matter of changing node parameter
        # <r:pages from='site' project='foo'/>
        # <r:img link='foo'/>
        # ...

        if node_kind_of?(Node)
          node_name = @context[:parent_node] || node
        else
          node_name = @context[:previous_node]
        end

        # make sure we do not use a new record in a find query:
        query = Node.build_find(count, pseudo_sql, :node_name => node_name, :raw_filters => raw_filters, :ref_date => "\#{#{current_date}}")

        unless query.valid?
          out parser_error(query.errors.join(' '), pseudo_sql.join(', '))
          return nil
        end


        if count == :count
          out "<%= #{query.finder(:count)} %>"
          return nil
        end

        klass = query.main_class

        if params[:else]
          # FIXME: else not working with safe_method_type ?
          finder, else_class, else_query = build_finder_for(count, params[:else], {})
          if finder && (else_query.nil? || else_query.valid?) && (else_class == klass || klass.ancestors.include?(else_class) || else_class.ancestors.include?(klass))
            klass = [klass] if count == :all
            {:method => "(#{query.finder(count)} || #{finder})", :class => klass, :query => query}
          else
            klass = count == :all ? [query.main_class] : query.main_class
            {:method => query.finder(count), :class => klass, :query => query}
          end
        else
          # FIXME: query_builder should respond to safe_type ===> {:method => ..., :class => ...}
          klass = count == :all ? [query.main_class] : query.main_class
          {:method => query.finder(count), :class => klass, :query => query}
        end
      end

      # Create an sql query to open a new context (passes its arguments to HasRelations#build_find)
      def build_finder_for(count, rel, params=@params, raw_filters = [])
        if (context = RubyLess::SafeClass.safe_method_type_for(node_class, [rel])) && !params[:in] && !params[:where] && !params[:from] && !params[:order] && raw_filters == []
          klass = context[:class]

          if klass.kind_of?(Array) && count == :all
            return ["#{node}.#{rel}", klass[0]]
          else
            return [(count == :all ? "[#{node}.#{rel}]" : "#{node}.#{rel}"), klass]
          end
        end

        rel ||= 'self'
        if (count == :first)
          if rel == 'self'
            return [node, node_class]
          elsif rel == 'main'
            return ["@node", Node]
          elsif rel == 'root'
            return ["(secure(Node) { Node.find(#{current_site[:root_id]})})", Node]
          elsif rel == 'start'
            return ["start_node", Node]
          elsif rel == 'visitor'
            return ["visitor.contact", Node]
          elsif rel =~ /^\d+$/
            return ["(secure(Node) { Node.find_by_zip(#{rel.inspect})})", Node]
          elsif node_name = find_stored(Node, rel)
            return [node_name, Node]
          elsif rel[0..0] == '/'
            rel = rel[1..-1]
            return ["(secure(Node) { Node.find_by_path(#{rel.inspect})})", Node]
          end
        end

        pseudo_sql, add_raw_filters = make_pseudo_sql(rel, params)
        raw_filters += add_raw_filters if add_raw_filters

        # FIXME: stored should be clarified and managed in a single way through links and contexts.
        # <r:void store='foo'>...
        # <r:link href='foo'/>
        # <r:pages from='foo'/> <-- this is just a matter of changing node parameter
        # <r:pages from='site' project='foo'/>
        # <r:img link='foo'/>
        # ...

        if node_kind_of?(Node)
          node_name = @context[:parent_node] || node
        else
          node_name = @context[:previous_node]
        end

        # make sure we do not use a new record in a find query:
        query = Node.build_find(count, pseudo_sql, :node_name => node_name, :raw_filters => raw_filters, :ref_date => "\#{#{current_date}}")

        unless query.valid?
          out parser_error(query.errors.join(' '), pseudo_sql.join(', '))
          return nil
        end


        if count == :count
          out "<%= #{query.finder(:count)} %>"
          return nil
        end

        klass = query.main_class

        if params[:else]
          # FIXME: else not working with safe_method_type ?
          finder, else_class, else_query = build_finder_for(count, params[:else], {})
          if finder && (else_query.nil? || else_query.valid?) && (else_class == klass || klass.ancestors.include?(else_class) || else_class.ancestors.include?(klass))
            ["(#{query.finder(count)} || #{finder})", klass, query]
          else
            [query.finder(count), query.main_class, query]
          end
        else
          [query.finder(count), query.main_class, query]
        end
      end

      # Build pseudo sql from the parameters
      # comments where ... from ... in ... order ... limit
      def make_pseudo_sql(rel, params=@params)
        parts   = [rel.dup]
        filters = []

        if params[:from]
          parts << params[:from]

          key_counter = 1
          while sub_part = params["from#{key_counter}".to_sym]
            key_counter += 1
            parts << sub_part
          end
        end

        if params[:where]
          parts[0] << " where #{params[:where]}"
        end

        if params[:in]
          parts[-1] << " in #{params[:in]}"
        end

        if group = params[:group]
          parts[-1] << " group by #{group}" unless parts[0] =~ /group by/
        end

        if order = params[:order]
          parts[-1] << " order by #{order}" unless parts[0] =~ /order by/
        end

        if paginate = params[:paginate]
          page_size = params[:limit].to_i
          page_size = 20 if page_size < 1
          parts[-1] << " limit #{page_size} paginate #{paginate.gsub(/[^a-z_A-Z]/,'')}"
        else
          [:limit, :offset].each do |k|
            next unless params[k]
            parts[-1] << " #{k} #{params[k]}" unless parts[0] =~ / #{k} /
          end
        end

        finders = [parts.join(' from ')]
        if params[:or]
          finders << params[:or]

          key_counter = 1
          while sub_or = params["or#{key_counter}".to_sym]
            key_counter += 1
            finders << sub_or
          end
        else
          or_clause = nil
        end

        return [finders, parse_raw_filters(params)]
      end

      # Parse special filters
      def parse_raw_filters(params)
        filters = []

        if value = params[:author]
          if stored = find_stored(User, value)
            filters << "TABLE_NAME.user_id = '\#{#{stored}.id}'"
          elsif value == 'current'
            filters << "TABLE_NAME.user_id = '\#{#{node}[:user_id]}'"
          elsif value == 'visitor'
            filters << "TABLE_NAME.user_id = '\#{visitor[:id]}'"
          elsif value =~ /\A\d+\Z/
            filters << "TABLE_NAME.user_id = '#{value.to_i}'"
          elsif value =~ /\A[\w\/]+\Z/
            # TODO: path, not implemented yet
          end
        end

        if value = params[:project]
          if stored = find_stored(Node, value)
            filters << "TABLE_NAME.project_id = '\#{#{stored}.get_project_id}'"
          elsif value == 'current'
            filters << "TABLE_NAME.project_id = '\#{#{node}.get_project_id}'"
          elsif value =~ /\A\d+\Z/
            filters << "TABLE_NAME.project_id = '#{value.to_i}'"
          elsif value =~ /\A[\w\/]+\Z/
            # TODO: path, not implemented yet
          end
        end

        if value = params[:section]
          if stored = find_stored(Node, value)
            filters << "TABLE_NAME.section_id = '\#{#{stored}.get_section_id}'"
          elsif value == 'current'
            filters << "TABLE_NAME.section_id = '\#{#{node}.get_section_id}'"
          elsif value =~ /\A\d+\Z/
            filters << "TABLE_NAME.section_id = '#{value.to_i}'"
          elsif value =~ /\A[\w\/]+\Z/
            # not implemented yet
          end
        end

        [:updated, :created, :event, :log].each do |k|
          if value = params[k]
            # current, same are synonym for 'today'
            filters << date_condition(value,"TABLE_NAME.#{k}_at",current_date)
          end
        end

        filters == [] ? nil : filters
      end

  end # Context
end # Zafu