module Zena
  module Use
    module QueryBuilder
      module ViewMethods
        def find_node_by_zip(zip)
          return nil unless zip
          secure(Node) { Node.find_by_zip(zip) }
        end
      end # ViewMethods

      # 1. try Zafu
      #   <r:images in='site'>
      #
      # 2. r_unknown
      #   try RubyLess.translate(xxxxxx, node) <-- pass context
      #
      # 3. helper (view) tries to resolve safe_method_type as RubyLess or PseudoSQL
      module ZafuMethods
        include RubyLess
        # The :class argument in this method is only used when the String is not a literal value
        safe_method [:find, String] => {:method => 'nil', :pre_processor => :get_finder_type, :class => NilClass}
        safe_method [:find, Number] => {:method => :find_node_by_zip, :class => Node, :nil => true, :accept_nil => true}

        def self.included(base)
          base.process_unknown :querybuilder_eval
        end

        # Pre-processing of the 'find("...")' method.
        def get_finder_type(string)
          finder = build_finder(:first, string, {})
          TypedString.new(finder.delete(:method), finder)
        end

        # Resolve unknown methods by trying to build a pseudo-sql query with QueryBuilder.
        def querybuilder_eval(method = @method)
          return nil if node.klass.kind_of?(Array) # list context

          if method =~ /^\d+$/
            finder = {:method => "find_node_by_zip(#{method})", :class => Node, :nil => true}
          else
            count  = get_count(method, @params)
            finder = build_finder(count, method, @params)
          end

          expand_with_finder(finder)
          true
        rescue ::QueryBuilder::Error => err
          parser_error(err.message)
        end

        # Select the most pertinent error between RubyLess processing errors and QueryBuilder errors.
        def show_errors
          if @method =~ / in / || ([:find, :in, :where, :or, :limit, :order] & @params.keys != [])
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

            query_opts = {
              :node_name            => @node_name,
              :raw_filters          => raw_filters,
              :rubyless_helper      => self,
              :link_both_directions => @params[:direction] == 'both',
            }


            query = node.klass.build_query(count.to_sym, pseudo_sql, query_opts)
            klass = query.main_class


            #unless query.valid?
            #  raise QueryException.new(query.errors.join(' '), pseudo_sql.join(', '))
            #end


            finder = get_finder(query, count)

            if count != :count && else_clause = @params[:else]
              else_clause = ::RubyLess.translate(else_clause, self)

              if else_clause.klass == Array
                or_klass = else_clause.opts[:array_content_class]
                if count == :all
                  # Get first common ancestor
                  common_klass = (klass.ancestors & or_klass.ancestors).detect {|x| x.kind_of?(Class)}
                  raise ::QueryBuilder::Error.new("Incompatible 'else' ([#{else_clause.klass}]) with finder ([#{klass}])") unless common_klass
                else
                  raise ::QueryBuilder::Error.new("Incompatible 'else' ([#{or_klass}]) with finder (#{klass})")
                end
              else
                if count == :first
                  # Get first common ancestor
                  common_klass = (klass.ancestors & else_clause.klass.ancestors).detect {|x| x.kind_of?(Class)}
                  raise ::QueryBuilder::Error.new("Incompatible 'else' (#{else_clause.klass}) with finder ([#{klass}])") unless common_klass
                else
                  raise ::QueryBuilder::Error.new("Incompatible 'else' (#{else_clause.klass}) with finder ([#{klass}])")
                end
              end


              finder = "(#{finder} || #{else_clause})"
              could_be_nil = else_clause.could_be_nil?
            else
              could_be_nil = true
            end

            if count == :count
              {:method => finder, :class => Number,  :query => query}
            elsif count == :all
              {:method => finder, :class => [klass], :query => query, :nil => could_be_nil}
            else
              {:method => finder, :class => klass,   :query => query, :nil => could_be_nil}
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
            query_string = query.to_s(count == :count ? :count : :find)
            "#{query.master_class}.do_find(#{count.inspect}, #{query_string})"
          end

          # Returns :all, :first or :count depending on the parameters and some introspection in the zafu tree
          def get_count(method, params)
            (%w{first all count}.include?(params[:find]) ? params[:find].to_sym : nil) ||
            ((params[:paginate] || child['each'] || child['group'] || Node.plural_relation?(method)) ? :all : :first)
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

            # [group by GROUP_CLAUSE] [order by ORDER_CLAUSE] [limit num(,num)] [offset num] [paginate key]

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

            if finders.size > 1
              finders = "(#{finders.join(') or (')})"
            else
              finders = finders.first
            end

            return [finders, parse_raw_filters(params)]
          end

          # Parse special filters
          # FIXME: replace all these with proper pseudo_sql (and destroy Zena::Db.date_condition).
          def parse_raw_filters(params)
            filters = []

            if value = params[:author]
              if stored = get_context_var('set_var', value) && stored.klass <= User
                filters << "TABLE_NAME.user_id = '\#{#{stored}.id}'"
              elsif value == 'current'
                filters << "TABLE_NAME.user_id = '\#{#{node(Node)}[:user_id]}'"
              elsif value == 'visitor'
                filters << "TABLE_NAME.user_id = '\#{visitor[:id]}'"
              elsif value =~ /\A\d+\Z/
                filters << "TABLE_NAME.user_id = '#{value.to_i}'"
              elsif value =~ /\A[\w\/]+\Z/
                # TODO: path, not implemented yet
              end
            end

            if value = params[:project]
              if stored = get_context_var('set_var', value) && stored.klass <= Node
                filters << "TABLE_NAME.project_id = '\#{#{stored}.get_project_id}'"
              elsif value == 'current'
                filters << "TABLE_NAME.project_id = '\#{#{node(Node)}.get_project_id}'"
              elsif value =~ /\A\d+\Z/
                filters << "TABLE_NAME.project_id = '#{value.to_i}'"
              elsif value =~ /\A[\w\/]+\Z/
                # TODO: path, not implemented yet
              end
            end

            if value = params[:section]
              if stored = get_context_var('set_var', value) && stored.klass <= Node
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
                filters << Zena::Db.date_condition(value,"TABLE_NAME.#{k}_at", get_context_var('set_var', 'date') || RubyLess::TypedString('main_date', Time))
              end
            end

            filters == [] ? nil : filters
          end
      end # ZafuMethods
    end # QueryBuilder
  end # Use
end # Zena