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
        #def safe_method_type(signature)
        #  super || pseudo_sql_method(signature)
        #end

        private
          def pseudo_sql_method(signature)
            rel, params = signature
            params ||= {}
            return nil unless params.kind_of?(Hash)

            count = get_count(rel, params)
            build_query(count, rel, params)
          end

          def build_query(count, rel, params)

            if !node.klass.respond_to?(:build_find)
              raise QueryException.new("No query builder for class #{node.klass}")
            end


            raw_filters = []

            if (count == :first)
              if rel == 'self'
                return {:method => node.name, :class => node.klass}
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
              # FIXME: elsif node.name = find_stored(Node, rel)
              # FIXME:   return {:method => node.name, :class => Node}
              elsif rel[0..0] == '/'
                rel = rel[1..-1]
                return {:method => "(secure(Node) { Node.find_by_path(#{rel.inspect})})", :class => Node}
              end
            end

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
              node_name = node.name #@context[:parent_node] || node
            else
              node_name = node.get(Node).name
            end

            current_date = context[:date] || 'main_date'
            query = Node.build_find(count.to_sym, pseudo_sql, :node_name => node_name, :raw_filters => raw_filters, :ref_date => "\#{#{current_date}}")

            unless query.valid?
              raise QueryException.new(query.errors.join(' '), pseudo_sql.join(', '))
            end


            if count == :count
              return {:method => query.finder(:count), :class => Number, :query => query}
            end

            klass = query.main_class

            # if params['else']
            #   # FIXME: else not working with safe_method_type ?
            #   finder, else_class, else_query = build_query(count, params['else'], {})
            #   if finder && (else_query.nil? || else_query.valid?) && (else_class == klass || klass.ancestors.include?(else_class) || else_class.ancestors.include?(klass))
            #     klass = [klass] if count == :all
            #     {:method => "(#{query.finder(count)} || #{finder})", :class => klass, :query => query}
            #   else
            #     klass = count == :all ? [query.main_class] : query.main_class
            #     {:method => query.finder(count), :class => klass, :query => query}
            #   end
            # else
            klass = count == :all ? [query.main_class] : query.main_class
            {:method => query.finder(count), :class => klass, :query => query}
            # end
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
      end # ViewMethods
    end # QueryBuilder
  end # Use
end # Zena