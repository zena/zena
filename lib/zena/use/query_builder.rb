module Zena
  module Use
    module QueryBuilder

      # 1. try Zafu
      #   <r:images in='site'>
      #
      # 2. r_unknown
      #   try RubyLess.translate(xxxxxx, node) <-- pass context
      #
      # 3. helper (view) tries to resolve safe_method_type as RubyLess or PseudoSQL
      module ZafuMethods

        def self.included(base)
          base.process_unknown :querybuilder_eval
        end

        # Resolve unknown methods by trying to build a pseudo-sql query with QueryBuilder.
        def querybuilder_eval
          return nil if node.klass.kind_of?(Array) # list context

          count  = get_count(@method, @params)
          finder = build_finder(count, @method, @params)

          expand_with_finder(finder)
          true
        rescue ::QueryBuilder::Error => err
          parser_error(err.message)
        end

        # Select the most pertinent error between RubyLess processing errors and QueryBuilder errors.
        def show_errors
          if @method =~ / in /
            # probably a query
            @errors.detect {|e| e =~ /Syntax/} || @errors.last
          else
            @errors.first
          end
        end

        # This method is called when we enter a new node context
        def node_context_vars(finder)
          sub_context = super
          query = finder[:query]
          if query && (pagination_key = query.pagination_key)
            node_count = set_var(sub_context, "#{pagination_key}_nodes")
            page_count = set_var(sub_context, "#{pagination_key}_count")
            curr_page  = set_var(sub_context, pagination_key)
            out "<% #{node_count} = #{query.to_s(:count)}; #{page_count} = (#{node_count} / #{query.page_size.to_f}).ceil; #{curr_page} = [1,params[:#{pagination_key}].to_i].max -%>"
            sub_context[:paginate] = pagination_key
          end
          sub_context
        end

        private
          def build_finder(count, rel, params = {})

            if !node.klass.respond_to?(:build_query)
              raise ::QueryBuilder::Error.new("No query builder for class #{node.klass}")
            end


            raw_filters = []
            pseudo_sql, add_raw_filters = get_pseudo_sql(rel, params)
            raw_filters += add_raw_filters if add_raw_filters

            # FIXME: stored should be clarified and managed in a single way through links and contexts.
            # <r:void store='foo'>...
            # <r:link href='foo'/>
            # <r:pages from='foo'/> <-- this is just a matter of changing node parameter
            # <r:pages from='site' project='foo'/>
            # <r:img link='foo'/>
            # ...

            if node.will_be?(Node)
              @node_name = node.name
            else
              @node_name = node.get(Node).name
            end

            query = node.klass.build_query(count.to_sym, pseudo_sql, :node_name => @node_name, :raw_filters => raw_filters, :rubyless_helper => self)
            klass = query.main_class


            #unless query.valid?
            #  raise QueryException.new(query.errors.join(' '), pseudo_sql.join(', '))
            #end


            finder = get_finder(query, count)

            if count == :count
              {:method => finder, :class => Number,  :query => query}
            elsif count == :all
              {:method => finder, :class => [klass], :query => query}
            else
              {:method => finder, :class => klass,   :query => query}
            end

            # if params['else']
            #   # FIXME: else not working with safe_method_type ?
            #   finder, else_class, else_query = build_finder(count, params['else'], {})
            #   if finder && (else_query.nil? || else_query.valid?) && (else_class == klass || klass.ancestors.include?(else_class) || else_class.ancestors.include?(klass))
            #     klass = [klass] if count == :all
            #     {:method => "(#{query.finder(count)} || #{finder})", :class => klass, :query => query}
            #   else
            #     klass = count == :all ? [query.main_class] : query.main_class
            #     {:method => query.finder(count), :class => klass, :query => query}
            #   end
            # else
            # end
          end

          # Return Ruby finder from a query
          def get_finder(query, count)
            query_string   = query.to_s(count == :count ? :count : :find)
            uses_node_name = query_string =~ /#{@node_name}\./
            "#{@node_name}.do_find(#{count.inspect}, #{query_string}, #{uses_node_name ? 'true' : 'false'})"
          end

          # Returns :all, :first or :count depending on the parameters and some introspection in the zafu tree
          def get_count(method, params)
            (%w{first all count}.include?(params[:find]) ? params[:find].to_sym : nil) ||
            (params[:paginate] || child['each'] || child['group'] || Node.plural_relation?(method)) ? :all : :first
          end

          # Build pseudo sql from the parameters
          # comments where ... from ... in ... order ... limit
          def get_pseudo_sql(rel, params)
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

            # [limit num(,num)] [offset num] [paginate key] [group by GROUP_CLAUSE] [order by ORDER_CLAUSE]

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

            if group = params[:group]
              parts[-1] << " group by #{group}" unless parts[0] =~ /group by/
            end

            if order = params[:order]
              parts[-1] << " order by #{order}" unless parts[0] =~ /order by/
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

            if finders.size > 1
              finders = finders.map {|f| "(#{f})"}.join(' or ')
            else
              finders = finders.first
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
      end # ViewMethods
    end # QueryBuilder
  end # Use
end # Zena