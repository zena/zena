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

    # use all other tags as relations
    def r_unknown
      @params[:select] = @method
      r_context
    end


    # Enter a new context (<r:context find='all' method='pages'>). This is the same as '<r:pages>...</r:pages>'). It is
    # considered better style to use '<r:pages>...</r:pages>' instead of the more general '<r:context>' because the tags
    # give a clue on the context at start and end. Another way to open a context is the 'do' syntax: "<div do='pages'>...</div>".
    # FIXME: 'else' clause has been removed, find a solution to put it back.
    def r_context
      # DRY ! (build_finder_for, block)
      return parser_error("missing 'method' parameter") unless method = @params[:select]

      context = node_class.zafu_known_contexts[method]
      if context && @params.keys == [:select]
        open_context("#{node}.#{method}", context)
      elsif node_kind_of?(Node)
        count   = ['first','all','count'].include?(@params[:find]) ? @params[:find].to_sym : nil
        count ||= Node.plural_relation?(method) ? :all : :first
        finder, klass, query = build_finder_for(count, method, @params)
        return unless finder
        if node_kind_of?(Node) && !klass.ancestors.include?(Node)
          # moving out of node: store last Node
          @context[:previous_node] = node
        end
        if count == :all
          # plural
          do_list( finder, query, :node_class => klass)
        # elsif count == :count
        #   "<%= #{build_finder_for(count, method, @params)} %>"
        else
          # singular
          do_var(  finder, :node_class => klass)
        end
      else
        "unknown relation (#{method}) for #{node_class} class"
      end
    end

    def r_comments_to_publish
      open_context("visitor.comments_to_publish", :node_class => [Comment])
    end

    def r_to_publish
      open_context("visitor.to_publish", :node_class => [Version])
    end

    def r_proposed
      open_context("visitor.proposed", :node_class => [Version])
    end

    def r_redactions
      open_context("visitor.redactions", :node_class => [Version])
    end

    protected

      # Create an sql query to open a new context (passes its arguments to HasRelations#build_find)
      def build_finder_for(count, rel, params=@params, raw_filters = [])
        if (context = node_class.zafu_known_contexts[rel]) && !params[:in] && !params[:where] && !params[:from] && !params[:order] && raw_filters == []
          klass = context[:node_class]

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
          # FIXME: else not working with zafu_known_contexts
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