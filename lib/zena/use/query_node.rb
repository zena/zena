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
        disable_safe_read # ?
      end

      module ModelMethods
        def self.included(base)
          base.send(:include, ::QueryBuilder)
          base.extend ClassMethods
          base.query_compiler = Zena::Use::QueryNode::Compiler
          base.safe_method :db_attr => StringDictionary
        end

        # Find related nodes.
        # See Node#build_find for details on the options available.
        # TODO: do we need rubyless translate here ?
        def find(count, rel, opts = {})
          rel = [rel] if rel.kind_of?(String)

          if !opts[:skip_rubyless] && rel.size == 1 && type = RubyLess::SafeClass.safe_method_type_for(self.class, [rel.first])
            self.send(type[:method])
          else
            begin
              query = self.class.build_query(count, rel.first, :node_name => 'self')
            rescue ::QueryBuilder::SyntaxError => err
              return nil
            end
            self.class.do_find(count, eval(query.to_s))
          end
        end

        # Return a hash with the values contained in the SQL query with 'AS' (used with custom queries).
        def db_attr
          @db_attr ||= Hash[*@attributes.select do |key, value|
            !self.class.column_names.include?(key)
            # db fetch only: select 'now() - created_at AS age' ----> 'age' can be read
          end.flatten]
        end

      end # ModelMethods

      module ClassMethods
        include Zena::Acts::Secure::SecureResult

        # Return the name of the group used for custom queries
        def query_group
          visitor.site.host
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
            count_by_sql(query)
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
        set_default :order,   'position ASC, node_name ASC'
        set_default :context, 'self'
        after_process :insert_links_fields
        after_process :secure_query

        load_custom_queries ["#{RAILS_ROOT}/bricks/*/queries"]

        CORE_CONTEXTS = %w{parent project section}

        class << self
          attr_accessor :filter_fields

          def add_filter_field(key, fld_def)
            self.filter_fields[key] = fld_def
          end
        end

        self.filter_fields = {'id' => {:key => 'zip'}}
        add_filter_field 'now', Zena::Db::NOW

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

        # Overwrite this and take car to check for valid fields.
        def process_field(field_name)
          if processing_filter? && map_def = self.class.filter_fields[field_name]
            if map_def.kind_of?(String)
              return map_def
            elsif table_def = map_def[:table]
              table_to_use = needs_join_table(*table_def)
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
            column = @query.main_class.schema.columns[field_name]
            if column && column.indexed?
              if column.index == true
                group_name = column.type
              else
                group_name = column.index
              end

              index_table = @query.main_class.index_table_name(group_name)
              add_table(index_table)

              add_filter "#{table(index_table)}.node_id = #{table}.id"
              add_filter "#{table(index_table)}.key = #{quote(field_name)}"
              if group_name.to_s =~ /^ml_/
                add_filter "#{table(index_table)}.lang = #{quote(visitor.lang)}"
              end
              distinct!
              "#{table(index_table)}.value"
            else
              super # raises an error
            end
          end
        end

        # Process pagination parameter
        def process_param(pagination_key)
          "params[#{pagination_key.to_sym.inspect}]"
        end

        # Handle special case for 'class = ' and 'role = '
        def process_equal(left, right)
          if left == [:field, 'class'] && right[0] == :field
            if klass = Node.get_class(right[1])
              "#{field_or_attr('kpath')} = #{quote(klass.kpath)}"
            else
              raise QueryBuilder::QueryException.new("Unknown class #{right.last.inspect}.")
            end
          elsif left == [:field, 'role'] && right[0] == :field
            if role = Node.get_role(right[1])
              # FIXME: how to only add table once if the other clause in not an OR ?
              add_table('nodes_roles')
              "(#{table('nodes_roles')}.node_id = #{table('nodes')}.id AND #{table('nodes_roles')}.role_id = #{role.id})"
            end
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

        def process_function(arg, method)
          arg, method = process(arg), process(method)
          Zena::Db.sql_function(method, arg)
        end

        # ******** And maybe overwrite these **********
        def parse_custom_query_argument(key, value)
          return nil unless value
          super.gsub(/(RELATION_ID|NODE_ATTR)\(([^)]+)\)|(REF_DATE|NODE_ID)/) do
            type, value = $1, $2
            type ||= $3
            case type
            when 'RELATION_ID'
              role = value
              if rel = RelationProxy.find_by_role(role.singularize)
                rel[:id]
              else
                @errors << "could not find Relation '#{role}' in custom query"
                '-1'
              end
            when 'NODE_ATTR'
              attribute = value
              if Node.safe_method_type([attribute])
                insert_bind("#{@node_name}.#{attribute}")
              else
                @errors << "cannot read attribute '#{attribute}' in custom query"
                '-1'
              end
            when 'REF_DATE'
              context[:ref_date] ? insert_bind(context[:ref_date]) : 'now()'
            when 'NODE_ID'
              insert_bind("#{node_name}.id")
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
        def resolve_missing_table(query, table_alias, table_name)
          if table_name == 'links' || table_name =~ /^i_/
            # index table
            query.where.insert 0, "#{table_alias}.id = 0"
          else
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
            #when 'self'
            #  # Dummy context
            #  fields = ['id', 'id']
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
              add_filter "#{table}.id = #{current_site.root_id}"
              return true
            #when 'author', 'traductions', 'versions'
            #  # TODO: not implemented yet...
            #  return nil
            #when 'visitor'
            #  # Special pseudo-context
            #  @where << "#{table}.id = #{insert_bind("visitor.contact_id")}"
            #  return true
            end

            unless last?
              # We treat differently 'projects from ...' and 'projects in site'
              relation = relation.singularize
            end

            if CORE_CONTEXTS.include?(relation)
              # PREVIOUS_GROUP.id = NEW_GROUP.project_id
              add_table(main_table)
              add_filter "#{field_or_attr('id')} = #{field_or_attr("#{relation}_id", table(main_table, -1))}"
            else
              nil
            end
          end

          # Filtering of objects in scope
          def filter_relation(relation)
            case relation
            when main_table, 'children'
              # no filter
              add_table(main_table)
            else
              # Not a core context, try to filter by class type
              if klass = Node.get_class(relation)
                res_class = Zena::Acts::Enrollable.make_class(klass)
                set_main_class(res_class)

                add_table(main_table)
                add_filter "#{table}.kpath LIKE #{quote("#{res_class.kpath}%")}" unless res_class.kpath == 'N'
                true
              elsif role = Node.get_role(relation)
                klass = Zena::Acts::Enrollable.make_class(@query.main_class)
                klass.has_role role
                set_main_class(klass)

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
          def join_relation(relation)
            if rel = RelationProxy.find_by_role(relation.singularize)
              add_table(main_table)
              add_table('links')

              if context[:scope] == 'site'
                # Example: 'tagged in site' ==> any node with a 'tagged' relation (no need to
                # filter by source).
                distinct!
                add_filter "#{table('links')}.relation_id = #{rel.id}"
                add_filter "#{field_or_attr('id')} = #{table('links')}.#{rel.other_side}"
              elsif @opts[:link_both_directions]
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
              add_select "#{link_table}.id AS link_id"
              Zena::Use::Relations::LINK_ATTRIBUTES.each do |l|
                add_select "#{link_table}.#{l} AS l_#{l}"
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

