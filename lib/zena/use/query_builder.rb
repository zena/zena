module Zena
  module Use
    module QueryBuilder
      DATE_FIELD_REGEXP = %r{\d+[\.-/]\d+[\.-/]\d+}
      module ViewMethods
        include RubyLess
        safe_method [:query_parse, String] => {:class => String, :accept_nil => true}
        safe_method :query_errors => {:class => String, :nil => true}

        def find_node_by_zip(zip)
          return nil unless zip
          secure(Node) { Node.find_by_zip(zip) }
        end

        def query_errors
          @query_errors
        end

        def query(class_name, node_name, pseudo_sql, opts = {})
          type = opts[:type] || :find
          @query_errors = nil
          if klass = VirtualClass[class_name]
            begin
              query = klass.build_query(:all, pseudo_sql,
                :node_name       => node_name,
                :main_class      => klass,
                # We use 'zafu_helper' (which is slower) instead of 'self' because our helper needs to have helper modules
                # mixed in and strangely RubyLess cannot access the helpers from 'self'.
                :rubyless_helper => zafu_helper.helpers
              )
              if type == :count
                return klass.do_find(:count, eval(query.to_s(:count)))
              else
                return klass.do_find(:all, eval(query.to_s))
              end
            rescue ::QueryBuilder::Error => err
              @query_errors = "<span class='query'>#{pseudo_sql}</span> <span class='error'>#{err}</span>"
            end
          end
          # error
          type == :count ? 0 : nil
        end

        # Takes a hash of parameters and builds query arguments for SQLiss
        # the query ends up like ' AND param_name = "foo" AND param_name > 35'...
        def query_parse(params)
          params ||= {}
          res = []
          if params.kind_of?(String)
            return params
          elsif params.kind_of?(Hash)
            params.each do |k,v|
              clause = query_build_clause(k,v)
              res << clause unless clause.blank?
            end
          end
          res.empty? ? '1=1' : res.join(' and ')
        end

        private
          # Transforms special syntax into SQLiss. Argument can be
          #
          #    ''          ==> (empty fields are ignored)
          #    '""'        ==> key = ""
          #    '"null"'    ==> key = "null"
          #    'null'      ==> key is null
          #    'foobar'    ==> key = "foobar"
          #    '> 45'      ==> key > 45
          #    '10..20'    ==> key >= 10 and key <= 20
          #    '%bar'      ==> key like "%bar"
          #    '"foo%"'    ==> key = "foo%"
          def query_build_clause(key, arg)
            first = arg.first
            return "not (#{query_build_clause(key, arg[1..-1])})" if first == '!'
            if ["'", '"'].include?(first)
              return "#{key} = #{arg}"
            end

            if arg =~ DATE_FIELD_REGEXP
              # FIXME: Use to_utc and date function in Zena::Db
              arg = query_parse_dates(arg)
              first = arg.first
            end

            if ['>','<','='].include?(first)
              "#{key} #{arg}"
            elsif arg == 'null'
              "#{key} is null"
            elsif arg == ''
              # ignore
              ''
            elsif arg =~ /\*/
              # like
              "#{key} like #{arg.gsub('*','%').inspect}"
            elsif arg =~ /^(.+)\.\.(.+)$/
              # interval
              "#{key} >= #{$1} and #{key} <= #{$2}"
            elsif arg =~ /^\d+$/
              # number
              "#{key} = #{arg}"
            elsif first == "'"
              "#{key} = #{arg}"
            else
              "#{key} = #{arg.inspect}"
            end
          end

          def query_parse_dates(str)
            str.gsub(DATE_FIELD_REGEXP) do |date_str|
              if date = DateTime.parse(date_str) rescue nil
                date.strftime("'%Y-%m-%d'")
              else
                date_str
              end
            end
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
        safe_method [:find,  String] => {:method => 'nil', :pre_processor => :get_type_for_find,  :class => NilClass}
        safe_method [:count, String] => {:method => '0',   :pre_processor => :get_type_for_count, :class => Number  }
        safe_method [:find,  Number] => {:method => :find_node_by_zip, :class => Node, :nil => true, :accept_nil => true}

        def self.included(base)
          base.process_unknown :querybuilder_eval
        end

        # Dynamic query mocks the QueryBuilder::Query
        class DynamicQuery
          def initialize(default, node, sql)
            @default, @node, @sql = default, node, sql
          end

          def to_s(type = :find)
            base = "'#{@node.klass}', #{@node.to_s.inspect}, #{@sql}"
            case type
            when :find
              return "query(#{base})"
            else
              return "query(#{base}, :type => #{type.inspect})"
            end
          end

          # Pass all other methods to the default query.
          def method_missing(meth, *args)
            @default.send(meth, *args)
          end
        end

        # Open a list context with a query comming from the url params. Default param name is
        # "qb"
        def r_query
          return parser_error("Cannot be used in list context (#{node.class_name})") if node.list_context?
          return parser_error("Missing 'default' query") unless default_psql = @params[:default]

          begin
            default = build_finder(:all, default_psql, {})
            default_query = default[:query]
          rescue ::QueryBuilder::Error => err
            return parser_error(err.message)
          end

          klass = [default_query.main_class]

          can_be_nil = true
          if sql = @params[:eval]
            sql = RubyLess.translate(self, sql)
            unless sql.klass <= String
              return parser_error("Invalid compilation result for #{sql.inspect} (#{sql.klass})")
            end
            can_be_nil = sql.opts[:nil]
          elsif sql = @params[:select]
            sql = RubyLess.translate_string(self, sql)
            can_be_nil = sql.opts[:nil]
          else
            sql = "params[:qb]"
          end

          if can_be_nil
            sql = "#{sql} || #{default_psql.inspect}"
          end

          query = DynamicQuery.new(default_query, node, sql)
          expand_with_finder(:method => query.to_s, :class => [query.main_class], :nil => true, :query => query)
        end

        # Pre-processing of the 'find("...")' method.
        def get_type_for_find(string)
          finder = build_finder(get_count(string, {}), string, {})
          TypedString.new(finder.delete(:method), finder)
        rescue ::QueryBuilder::Error => err
          out parser_error(err.message)
          nil
        end

        # Pre-processing of the 'count("...")' method.
        def get_type_for_count(string)
          finder = build_finder(:count, string, {})
          TypedString.new(finder.delete(:method), finder)
        end

        # Resolve unknown methods by trying to build a pseudo-sql query with QueryBuilder.
        def querybuilder_eval(method = @method)
          node = single_node

          if method =~ /^\d+$/
            finder = {:method => "find_node_by_zip(#{method})", :class => Node, :nil => true}
          else
            count  = get_count(method, @params)
            finder = build_finder(count, method, @params)
          end

          if count == :count && @blocks.empty?
            out "<%= #{finder[:method]} %>"
          else
            expand_with_finder(finder)
          end
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
          if query && ((pagination_key = query.pagination_key) || child['count'])
            node_count = get_var_name('paginate', 'nodes', sub_context)
            set_context_var('set_var', 'count', RubyLess::TypedString.new(node_count, Number))

            res = "#{node_count} = Node.do_find(:count, #{query.to_s(:count)})"
            if pagination_key
              # Full pagination needed
              set_context_var('paginate', 'key', pagination_key, sub_context)

              page_count = get_var_name('paginate', 'count', sub_context)
              curr_page  = get_var_name('paginate', 'current', sub_context)

              # Give access to the page number through the pagination key.
              set_context_var('set_var', pagination_key, RubyLess::TypedString.new(curr_page, Number))
              # Give access to page_count and count
              # FIXME: DOC
              set_context_var('set_var', 'page_count', RubyLess::TypedString.new(page_count, Number))

              res << "; #{page_count} = (#{node_count} / #{query.page_size.to_f}).ceil; #{curr_page} = [1,params[:#{pagination_key}].to_i].max"
            end

            out "<% #{res} %>"

          elsif finder[:method].kind_of?(RubyLess::TypedString)
            # Hash passed with :zafu => {} is inserted into context
            sub_context.merge!(finder[:method].opts[:zafu] || {})
          end

          sub_context[:has_link_id] = query && query.select_keys.include?('link_id')

          sub_context
        end

        private
          def single_node
            node = self.node
            while node.list_context?
              node = node.up
              if !node
                raise ::QueryBuilder::Error.new("Could not access node context  query builder from list #{self.node.class_name}")
              end
            end
            node
          end

          # Build a Query object from SQLiss.
          def build_query(count, pseudo_sql, raw_filters = [])
            node = single_node

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

            if count != :count && params[:else]
              begin
                else_clause = RubyLess.translate(self, params[:else])
              rescue RubyLess::Error
                else_clause = RubyLess.translate(self, "find(#{params[:else].inspect})")
              end

              if else_clause.klass == Array
                else_klass = else_clause.opts[:elem]
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
            ((params[:paginate] || child['each'] || child['group'] || Node.plural_relation?(method.split(' ').first)) ? :all : :first)
          end

          # Build SQLiss from the parameters
          # comments where ... from ... in ... order ... limit
          def get_pseudo_sql(rel, params)
            parts   = [rel.dup]
            filters = []
            group_order_limit = ''

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
              group_order_limit << " group by #{group}" unless parts[0] =~ /group by/
            end

            if order = params[:order]
              group_order_limit << " order by #{order}" unless parts[0] =~ /order by/
            end

            if paginate = params[:paginate]
              page_size = params[:limit].to_i
              page_size = 20 if page_size < 1
              group_order_limit << " limit #{page_size} paginate #{paginate.gsub(/[^a-z_A-Z]/,'')}"
            else
              [:limit, :offset].each do |k|
                next unless params[k]
                group_order_limit << " #{k} #{params[k]}" unless parts[0] =~ / #{k} /
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
              finders = "(#{finders.join(') or (')})#{group_order_limit}"
            else
              finders = finders.first + group_order_limit
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