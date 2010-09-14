module Zena
  module Use
    module QueryBuilder
      module ViewMethods
        def find_node_by_zip(zip)
          return nil unless zip
          secure(Node) { Node.find_by_zip(zip) }
        end

        def query(class_name, node_name, pseudo_sql)
          klass = get_class(class_name)
          begin
            query = klass.build_query(:all, pseudo_sql,
              :node_name       => node_name,
              :main_class      => klass,
              # We use 'zafu_helper' (which is slower) instead of 'self' because our helper needs to have helper modules
              # mixed in and strangely RubyLess cannot access the helpers from 'self'.
              :rubyless_helper => zafu_helper.helpers
            )
          rescue ::QueryBuilder::Error => err
            # FIXME: how to return error messages to the user ?
            nil
          end

          klass.do_find(:all, eval(query.to_s))
        end
      end # ViewMethods

      # 1. try Zafu
      #   <r:images in='site'>
      #
      # 2. r_unknown
      #   try RubyLess.translate(node, xxxxxx) <-- pass context
      #
      # 3. helper (view) tries to resolve safe_method_type as RubyLess or PseudoSQL
      module ZafuMethods
        QB_KEYS = [:find, :from, :else, :in, :where, :or, :limit, :order]

        include RubyLess
        # The :class argument in this method is only used when the String is not a literal value
        safe_method [:find, String] => {:method => 'nil', :pre_processor => :get_finder_type, :class => NilClass}
        safe_method [:find, Number] => {:method => :find_node_by_zip, :class => Node, :nil => true, :accept_nil => true}

        def self.included(base)
          base.process_unknown :querybuilder_eval
        end

        # Open a list context with a query comming from the url params. Default param name is
        # "qb"
        def r_query
          return parser_error("Cannot be used in list context (#{node.class_name})") if node.list_context?
          return parser_error("Missing 'default' query") unless default = @params[:default]
          return parser_error("No query compiler for (#{node.class_name})") if !node.klass.respond_to?(:build_query)


          default_query = build_query(:all, default)
          klass = [default_query.main_class]

          if sql = @params[:eval]
            sql = RubyLess.translate(self, sql)
            unless sql.klass <= String
              return parser_error("Invalid compilation result for #{sql.inspect} (#{sql.klass})")
            end
          elsif sql = @params[:text]
            sql = RubyLess.translate_string(self, sql)
          else
            sql = "params[:qb]"
          end

          method = "query('#{node.klass}', #{node.to_s.inspect}, #{sql} || #{default.inspect})"

          expand_with_finder(:method => method, :class => klass, :nil => true)
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
        rescue ::QueryBuilder::Error => err
          parser_continue(err.message)
        end

        # Select the most pertinent error between RubyLess processing errors and QueryBuilder errors.
        def show_errors
          if @method =~ / in | where | from / || (QB_KEYS & @params.keys != [])
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
            set_context_var('paginate', 'key', pagination_key, sub_context)

            node_count = get_var_name('paginate', 'nodes', sub_context)
            page_count = get_var_name('paginate', 'count', sub_context)
            curr_page  = get_var_name('paginate', 'current', sub_context)

            # Give access to the pagination key.
            set_context_var('set_var', pagination_key, RubyLess::TypedString.new(curr_page, Number))

            out "<% #{node_count} = Node.do_find(:count, #{query.to_s(:count)}); #{page_count} = (#{node_count} / #{query.page_size.to_f}).ceil; #{curr_page} = [1,params[:#{pagination_key}].to_i].max -%>"
          elsif finder[:method].kind_of?(RubyLess::TypedString)
            # Hash passed with :zafu => {} is inserted into context
            sub_context.merge!(finder[:method].opts[:zafu] || {})
          end

          sub_context[:has_link_id] = query && query.select.to_s =~ / AS link_id/

          sub_context
        end

        private
          # Build a Query object from pseudo sql.
          def build_query(count, pseudo_sql, raw_filters = [])

            if !node.klass.respond_to?(:build_query)
              raise ::QueryBuilder::Error.new("No query builder for class #{node.klass}")
            end

            query_opts = {
              :node_name            => node.name,
              :raw_filters          => raw_filters,
              :rubyless_helper      => self,
              :link_both_directions => @params[:direction] == 'both',
              # set starting class in case we need to search for relations
              :main_class           => node.klass,
            }

            node.klass.build_query(count.to_sym, pseudo_sql, query_opts)
          end

          # Build a finder method and class from a query (relation) and params.
          def build_finder(count, rel, params = {})
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

            query = build_query(count, pseudo_sql, raw_filters)

            klass = query.main_class

            finder = get_finder(query, count)

            if count != :count && else_clause = @params[:else]
              else_clause = RubyLess.translate(self, else_clause)

              if else_clause.klass == Array
                else_klass = else_clause.opts[:array_content_class]
                if count == :all
                  # Get first common ancestor
                  common_klass = (klass.ancestors & else_klass.ancestors).detect {|x| x.kind_of?(Class)}
                  raise ::QueryBuilder::Error.new("Incompatible 'else' ([#{else_clause}]) with finder ([#{klass}])") unless common_klass
                else
                  raise ::QueryBuilder::Error.new("Incompatible 'else' ([#{else_klass}]) with finder (#{klass})")
                end
              else
                if count == :first
                  # Get first common ancestor
                  common_klass = (klass.ancestors & else_clause.klass.ancestors).detect {|x| x.kind_of?(Class)}
                  raise ::QueryBuilder::Error.new("Incompatible 'else' (#{else_clause.klass}) with finder (#{klass})") unless common_klass
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
                filters << Zena::Db.date_condition(value,"TABLE_NAME.#{k}_at", get_context_var('set_var', 'date')) # || RubyLess::TypedString('main_date', Time))
              end
            end

            filters == [] ? nil : filters
          end
      end # ZafuMethods
    end # QueryBuilder
  end # Use
end # Zena