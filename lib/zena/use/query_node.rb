require 'query_builder'

# Since QueryNode uses a special scope (secure_scope) that needs to be evaluated _in the query string_, you cannot
# use query.sql. You have to use: eval query.to_s. This is not an issue since normal useage for QueryNode is to be
# compilated into an ERB template.
module Zena
  module Use
    module QueryNode

      class StringDictionary
        include RubyLess
        safe_method ['[]', String] => {:class => String, :nil => true}
      end

      module ModelMethods
        def self.included(base)
          base.class_eval do
            include ::QueryBuilder
            extend ClassMethods
            self.query_compiler = Zena::Use::QueryNode::Compiler
            safe_method :db_attr => StringDictionary
            safe_method [:first, String]  => {:class => Node, :nil => true, :method => 'safe_first'}
          end
        end

        def safe_first(query)
          find(:first, query, :skip_rubyless => true)
        end

        # Find related nodes.
        # See Node#build_find for details on the options available.
        # TODO: do we need rubyless translate here ? It should be removed.
        def find(count, pseudo_sql = nil, opts = {})
          if pseudo_sql.nil?
            pseudo_sql = count
            count = Node.plural_relation?(pseudo_sql.split(' ').first) ? :all : :first
          end
          if !opts[:skip_rubyless] && type = RubyLess::SafeClass.safe_method_type_for(self.class, [pseudo_sql])
            self.send(type[:method])
          else
            begin
              query = self.class.build_query(count, pseudo_sql,
                :node_name       => 'self',
                :main_class      => virtual_class,
                :rubyless_helper => (opts[:rubyless_helper] || virtual_class), # should it be || self ?
                :default         => opts[:default]
              )
              if limit = opts[:limit]
                query.limit  = " LIMIT #{limit.to_i}"
                query.offset = " OFFSET #{opts[:offset].to_i}"
              end
            rescue ::QueryBuilder::Error => err
              return opts[:errors] ? err : nil
            end

            type = [:all, :first].include?(count) ? :find : :count

            Node.do_find(count, eval(query.to_s(type)))
          end
        end

        # Return a hash with the values contained in the SQL query with 'AS' (used with custom queries).
        def db_attr
          @db_attr ||= Hash[*@attributes.select do |key, value|
            !self.class.column_names.include?(key)
            # db fetch only: select 'now() - created_at AS age' ----> 'age' can be read
          end.flatten]
        end

        def start_node_zip
          self.zip
        end
      end # ModelMethods

      module ClassMethods
        include Zena::Acts::Secure::SecureResult

        # Return the name of the group used for custom queries
        def query_group
          visitor.site.host
        end

        def sfind(sqliss)
          query = Node.build_query(:all, sqliss,
            :default => {:scope => 'site'}
          )
          Node.do_find(:all, eval(query.to_s(:find)))
        end

        # Find a node and propagate visitor
        def do_find(count, query)
          case count
          when :all
            res = find_by_sql(query)
            secure_result(res)
          when :first
            res = find_by_sql(query).first
            secure_result(res)
          when :count
            # query can be a number when we use the 'query' helper to count.
            query.kind_of?(Fixnum) ? query : count_by_sql(query)
          else
            nil
          end
        end
      end

      class Compiler < QueryBuilder::Processor
        attr_reader :context # ?
        set_main_table 'nodes'
        set_main_class 'Node'
        set_default :scope,   'self'
        set_default :order,   'position ASC, title ASC'
        set_default :context, 'self'
        after_process :insert_links_fields
        after_process :secure_query

        load_custom_queries Bricks.paths_for('zena/queries')

        CORE_CONTEXTS = %w{parent project section}

        # Resolve 'main_class' from a class name.
        def resolve_main_class(class_name)
          VirtualClass[class_name]
        end

        class << self
          attr_accessor :filter_fields

          def add_filter_field(key, fld_def)
            self.filter_fields[key] = fld_def
          end
        end

        # Enables filters like "where id = 45" or "where parent_id = #{params[:parent_id]}"
        self.filter_fields = {
          'id'         => {:key => 'zip'},          # alias   source   target   filter
          'parent_id'  => {:key => 'zip', :table => ['jnode', 'nodes', 'nodes', 'TABLE2.id = TABLE1.parent_id AND TABLE2.site_id = TABLE1.site_id']},
          'project_id' => {:key => 'zip', :table => ['jnode', 'nodes', 'nodes', 'TABLE2.id = TABLE1.project_id AND TABLE2.site_id = TABLE1.site_id']},
          'section_id' => {:key => 'zip', :table => ['jnode', 'nodes', 'nodes', 'TABLE2.id = TABLE1.section_id AND TABLE2.site_id = TABLE1.site_id']},
          'now'        => Zena::Db::NOW,
        }

        # Scope current context with previous context.
        # For example:
        #                          current         previous
        #  ['parent_id', 'id'] ==> no1.parent_id = nodes.id
        def scope_fields(scope)
          case scope
          when 'self'
            ['parent_id', 'id']
          when *CORE_CONTEXTS
            last? ? %W{#{scope}_id #{scope}_id} : %W{#{scope}_id id}
          when 'site', main_table
            # not an error, but do not scope
            []
          else
            #if CORE_CONTEXTS.include?(scope)
            # error
            nil
          end
        end

        def process_attr(attribute)
          case attribute
          when 'project_id', 'section_id', 'discussion_id'
            # Special accessor
            insert_bind "#{node_name}.get_#{attribute}"
          when 'id', 'parent_id'
            # Not RubyLess safe
            insert_bind "#{node_name}.#{attribute}"
          else
            # Use RubyLess
            super
          end
        end

        def get_scope_index_field(field_name)
          return nil if @query.main_class.real_class.column_names.include?(field_name)
          # scope index
          klass = @query.main_class
          if index_model = klass.kind_of?(VirtualClass) ? klass.idx_class : nil
            index_model = Zena.resolve_const(index_model) rescue NilClass
            if index_model < Zena::Use::ScopeIndex::IndexMethods && index_model.column_names.include?(field_name)
              table_to_use = add_key_value_table('scope_index', index_model.table_name) do |tbl_name|
                # This block is only executed once
                add_filter "#{table('nodes')}.id = #{tbl_name}.node_id"
              end
              "#{table_to_use}.#{field_name}"
            else
              # invalid field_name: ignore
              nil
            end
          else
            # no index model: ignore
            nil
          end
        end

        def process_idx_field(scope_field)
          scope_field
        end

        # Overwrite this and take care to check for valid fields.
        def process_field(field_name)
          if fld = @query.attributes_alias[field_name]
            # use custom query alias value defined in select clause: 'custom_a AS validation'
            return processing_filter? ? "(#{fld})" : fld
          elsif processing_filter? && map_def = self.class.filter_fields[field_name]
            # Special filter fields such as 'role', 'tag' or 'class'
            if map_def.kind_of?(String)
              return map_def
            elsif table_def = map_def[:table]
              use_name, source, target, filter = table_def
              table_to_use = add_key_value_table(use_name, target, map_def[:key]) do |tbl_name|
                # This block is only executed once
                add_filter filter.gsub(
                  'TABLE1', table(source)
                ).gsub(
                  'TABLE2', tbl_name
                )
              end
            else
              table_to_use = table
            end
            "#{table_to_use}.#{map_def[:key]}"
          elsif %w{id parent_id project_id section_id user_id}.include?(field_name) ||
            (Node.safe_method_type([field_name]) && Node.column_names.include?(field_name))
            "#{table}.#{field_name}"
          elsif @query.tables.include?('links') &&
               (key = field_name[/^l_(.+)$/,1]) &&
               (key == 'id' ||
                Zena::Use::Relations::LINK_ATTRIBUTES.include?(key.to_sym))
            "#{table('links')}.#{key}"
          elsif field_name == 'random'
            Zena::Db.sql_function(field_name, nil)
          else
            if processing_filter? && field_name =~ /^(.*)_ids?$/
              # tag_id = 33  ===> join links as lk, nodes as tt .......
              rel = $1

              # Fake field_or_attr so it does not use 'zip' on nodes
              context[:processing] = :relation
                if join_relation($1, 'jnode')
                  res = "#{table('jnode')}.zip"
                end
              context[:processing] = :filter

              return res
            end

            # property or real column

            # FIXME !!!! Why does this happen ?
            return nil if @query.main_class.columns.kind_of?(Array)


            column = @query.main_class.columns[field_name]
            if column && column.indexed?
              if column.index == true
                group_name = column.type
              elsif column.index =~ Property::Index::FIELD_INDEX_REGEXP
                # field in nodes
                return "#{table}.#{$1}"
              else
                group_name = column.index
              end

              index_table = @query.main_class.real_class.index_table_name(group_name)

              # We use the add_key_value_table rule to avoid inserting the
              # same index access twice.

              tbl = add_key_value_table(group_name, index_table, field_name) do |tbl_name|
                # This block is only executed once
                add_filter "#{tbl_name}.node_id = #{table}.id"
                add_filter "#{tbl_name}.key = #{quote(field_name)}"
                if group_name.to_s =~ /^ml_/
                  add_filter "#{tbl_name}.lang = #{quote(visitor.lang)}"
                end
                # no need for distinct, the new table makes a 1-1 relation
              end

              "#{tbl}.value"
            else
              super # raises an error
            end
          end
        end

        # Process pagination parameter
        def process_param(pagination_key)
          "params[#{pagination_key.to_sym.inspect}]"
        end

        # Handle special case for 'class = ' and 'role = ' and 'foo.date ='
        def process_equal(left, right)
          if (left == [:field, 'class'] || left == [:field, 'klass']) &&
             (right[0] == :field || right[0] == :string)
            if klass = Node.get_class(right.last)
              "#{field_or_attr('kpath')} = #{quote(klass.kpath)}"
            else
              raise ::QueryBuilder::Error.new("Unknown class #{right.last.inspect}.")
            end
          elsif left == [:field, 'role'] && (right[0] == :field || right[0] == :string)
            if role = Node.get_role(right[1])
              # FIXME: how to only add table once if the other clause in not an OR ?
              add_table('nodes_roles')
              "(#{table('nodes_roles')}.node_id = #{table('nodes')}.id AND #{table('nodes_roles')}.role_id = #{role.id})"
            end
          elsif left.first == :function && left.last.last == 'date'
            # transform "foo.date = baz"
            # [:function, [:field, "foo"], [:method, "date"]]
            # [:field, baz]
            # ==> into
            # "baz >= foo and foo < baz + 1 day"
            a = left[1]
            b = right
            process([:and, [:<=, b, a], [:<, a, [:+, b, [:interval, [:integer, '1'], 'day']]]])
          else
            super
          end
        end

        # Handle special case for 'class like '
        def process_like(left, right)
          if left == [:field, 'class'] && right[0] == :field
            if klass = Node.get_class(right[1])
              "#{field_or_attr('kpath')} LIKE #{quote(klass.kpath + '%')}"
            else
              raise QueryBuilder::QueryException.new("Unknown class #{right.last.inspect}.")
            end
          else
            process_op(:like, left, right)
          end
        end

        def resolve_scope_idx_fields(arg1, arg2)
          if arg1.first == :function
            # contact.log_at.year
            # arg1 = [:function, [:field, "tag"], [:method, "created_at"]]
            # arg2 = [:method, "year"]
            class_name = arg1[1][1]
            field_name = arg1[2][1]
            function  = arg2
          elsif arg1[0] == :field && arg2[0] == :method
            # contact.log_at  or  log_at.year
            # arg1 = [:field, "contact"]
            class_name = arg1[1]
            # arg2 = [:method, "name"]
            field_name = arg2[1]
            function   = nil
          else
            return [arg1, arg2]
          end

          scope_idx_field = "#{class_name}_#{field_name}"
          if fld = get_scope_index_field(scope_idx_field)
            return [[:idx_field, fld], function]
          else
            # not a scope index field
            return [arg1, arg2]
          end
        end

        def process_function(arg, method, *args)
          # Resolve scope index fields
          arg, method = resolve_scope_idx_fields(arg, method)
          if method
            arg, method = process(arg), process(method)
            args = [arg] + args.map{|a| process(a)}
            Zena::Db.sql_function(method, *args)
          else
            process(arg)
          end
        end

        # ******** And maybe overwrite these **********
        def parse_custom_query_argument(key, value)
          return nil unless value
          super.gsub(/(RELATION_ID|NODE_ATTR|SECURE_TABLE)\(([^)]+)\)|(REF_DATE|NODE_ID|VISITOR_LANG)/) do
            type, value = $1, $2
            type ||= $3
            case type
            when 'RELATION_ID'
              role = value
              if rel = RelationProxy.find_by_role(role.singularize)
                rel[:id]
              else
                raise ::QueryBuilder::Error.new("Custom query: could not find Relation '#{role}'")
              end
            when 'SECURE_TABLE'
              table_name = value
              add_filter "\#{secure_scope('#{table_name}')}"
            when 'NODE_ATTR'
              attribute = value
              if Node.safe_method_type([attribute])
                insert_bind("#{node_name}.#{attribute}")
              else
                # not found: consider it's a property
                insert_bind("#{node_name}.prop[#{attribute.inspect}]")
              end
            when 'REF_DATE'
              context[:ref_date] ? insert_bind(context[:ref_date]) : 'now()'
            when 'NODE_ID'
              insert_bind("#{node_name}.id")
            when 'VISITOR_LANG'
              insert_bind("visitor.lang")
            end
          end
        end

        # Special case 'in site' that is a noop scope and
        # just avoids the insertion of the default 'in parent' scope.
        def need_join_scope?(scope_name)
          scope_name != 'site'
        end

        # This is used to avoid finding random indexed objects or links in clauses with and without link filters
        # like this: "image or icon" ('image' is a filter in 'parent' scope, 'icon' is a
        # relation found through links).
        def resolve_missing_table(query, table_name, table_alias)
          if table_name =~ /^idx_nodes/
            # index tables
            query.where.insert 0, "#{table_alias}.node_id = 0"
          elsif table_name == 'links' || table_name =~ /^idx_/
            # index tables
            query.where.insert 0, "#{table_alias}.id = 0"
          else
            # Raise an error
            super
          end
        end

        private
          # Change class
          def class_relation(relation)
            case relation
            when 'comment', 'comments'
              if last?
                change_processor Comment.query_compiler, :rubyless_helper => @rubyless_helper
                # no need to load discussions, versions and all the mess
                add_table('comments')
                add_filter "#{table('comments')}.discussion_id = #{process_attr('discussion_id')}"
              else
                after_process # Make sure we secure the current part
                change_processor Comment.query_compiler

                add_table('discussions')
                add_table('comments')
                add_filter "#{table('discussions')}.node_id = #{table('nodes')}.id"
                add_filter "#{table('comments')}.discussion_id = #{table('discussions')}.id"
                # after_parse
              end
            else
              return nil
            end
          end

          # Moving to another context without a join table
          def context_relation(relation)
            # Not sure we need all these anymore...
            case relation
            when 'self'
              # Special pseudo-context
              add_table(main_table)
              add_filter "#{field_or_attr('id')} = #{field_or_attr('id', table(main_table, -1))}"
              return true
            #when 'parent', 'project', 'section'
            #  # Core contexts
            #  fields = ['id', "#{relation}_id"]
            #when 'parents', 'projects', 'sections'
            #  if @table_counter[main_table] > 0 || @tables.include?('links')
            #    fields = ['id', "#{relation[0..-2]}_id"]
            #  end
            when 'root'
              # Special pseudo-context
              add_table(main_table)
              set_main_class(VirtualClass['Project'])
              add_filter "#{table}.id = #{current_site.root_id}"
              return true
            #when 'author', 'traductions', 'versions'
            #  # TODO: not implemented yet...
            #  return nil
            when 'visitor'
              # Special pseudo-context
              add_table(main_table)
              set_main_class(VirtualClass.find_by_kpath(visitor.prototype.kpath))
              add_filter "#{table}.id = #{insert_bind("visitor.node_id")}"
              return true
            end

            unless last?
              # We treat differently 'projects from ...' and 'projects in site'
              relation = relation.singularize
            end


            if relation =~ /^(.+):(.+)$/
              class_name, relation = $1, $2
            end

            if class_name
              # We have named the relation, set main_class
              # We should also insert class filter...
              if klass = Node.get_class(class_name)
                set_main_class(klass)
                kpath_filter = ".kpath LIKE #{quote("#{klass.kpath}%")}" unless klass.kpath == 'N'
              else
                raise QueryBuilder::QueryException.new("Unknown class #{klass} in scope '#{class_name}:#{scope}'.")
              end
            else
              klass = nil
            end

            if relation == 'start'
              add_table(main_table)
              add_filter "#{field_or_attr('zip')} = #{insert_bind('start_node_zip')}"
              add_filter "#{table}.site_id = #{insert_bind('current_site.id')}"
              if kpath_filter
                add_filter "#{table}#{kpath_filter}"
              end
              return true
            end

            if CORE_CONTEXTS.include?(relation)
              unless class_name
                if %w{project section}.include?(relation)
                  set_main_class(VirtualClass[relation.capitalize])
                else
                  set_main_class(VirtualClass['Node'])
                end
              end

              # PREVIOUS_GROUP.id = NEW_GROUP.project_id
              add_table(main_table)
              add_filter "#{field_or_attr('id')} = #{field_or_attr("#{relation}_id", table(main_table, -1))}"
              if kpath_filter
                add_filter "#{table}#{kpath_filter}"
              end
              true
            else
              nil
            end
          end

          # Filtering of objects in scope
          def filter_relation(relation)
            if [main_table, 'children'].include?(relation)
              # no filter
              add_table(main_table)
            else
              # Not a core context, try to filter by class type
              if klass = @filter_relation_class || Node.get_class(relation)
                # Relation was found in 'join_relation'
                @filter_relation_class = nil
                set_main_class(klass)
                res_class = klass

                add_table(main_table)
                add_filter "#{table}.kpath LIKE #{quote("#{res_class.kpath}%")}" unless res_class.kpath == 'N'
                true
              elsif role = Node.get_role(relation)
                if klass = VirtualClass.find_by_kpath(role.kpath)
                  set_main_class(klass)
                end

                add_table(main_table)
                add_table('nodes_roles')
                add_filter "#{table('nodes_roles')}.node_id = #{table('nodes')}.id"
                add_filter "#{table('nodes_roles')}.role_id = #{role.id}"
                true
              else
                # unknown class
                nil
              end
            end
          end

          # Moving to another context through 'joins'
          def join_relation(relation, use_name = nil)
            if context[:scope] == 'site'
              # Example: 'icons in site' ==> any node with an 'icon' relation (no need to filter by source).
              if @filter_relation_class = Node.get_class(relation)
                return nil
              end
              source_kpath = nil
            else
              source_kpath = @query.main_class.kpath
            end

            if rel = RelationProxy.find_by_role(relation.singularize, source_kpath)
              if use_name
                # Doing a jnode.. (node for filtering), we need to reverse relation
                rel.side = rel.side == :source ? :target : :source
                add_table(use_name, main_table)
              else
                add_table(main_table)
                set_main_class(rel.other_vclass)
              end

              add_table('links')

              if context[:scope] == 'site'
                distinct!
                add_filter "#{table('links')}.relation_id = #{rel.id}"
                add_filter "#{field_or_attr('id')} = #{table('links')}.#{rel.other_side}"
              elsif @opts[:link_both_directions]
                # TODO: Just detect same source and target roles.
                # source --> target && target --> source
                add_filter "#{table('links')}.relation_id = #{rel.id}"
                source = "#{table('links')}.#{rel.link_side} = #{field_or_attr('id', table(main_table,-1))} AND #{field_or_attr('id')} = #{table('links')}.#{rel.other_side}"
                target = "#{table('links')}.#{rel.other_side} = #{field_or_attr('id', table(main_table,-1))} AND #{field_or_attr('id')} = #{table('links')}.#{rel.link_side}"
                add_filter "(#{source} OR #{target})"
              else
                # source --> target
                add_filter "#{table('links')}.#{rel.link_side} = #{field_or_attr('id', table(main_table,-1))}"
                add_filter "#{table('links')}.relation_id = #{rel.id}"
                add_filter "#{field_or_attr('id')} = #{table('links')}.#{rel.other_side}"
              end
              true
            else
              nil
            end
          end

          def secure_query
            return if this != self
            add_filter "\#{secure_scope('#{table}')}"
          end

          def insert_links_fields
            if @query.tables.include?('links')
              link_table = table('links')
              unless @query.select
                @query.select = ["#{@query.main_table}.*"]
              end
              add_select("#{link_table}.id", 'link_id')
              Zena::Use::Relations::LINK_ATTRIBUTES.each do |l|
                add_select("#{link_table}.#{l}", "l_#{l}")
              end
            end
          end

          def node_name
            @context[:node_name]
          end
      end # Compiler
    end # QueryNode
  end # Use
end # Zena

