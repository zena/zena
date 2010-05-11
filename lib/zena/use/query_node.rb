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
          base.send(:include, QueryBuilder)
          base.extend ClassMethods
          base.query_compiler = Zena::Use::QueryNode::Compiler
          base.safe_method :db_attr => StringDictionary
        end

        # Find a node and propagate visitor
        def do_find(count, query, uses_source = true, klass = Node)
          return nil if query.empty?
          if new_record? && uses_source
            # do not run query if it depends on the source and the source is not a proper Node
            return nil
          end

          case count
          when :all
            res = klass.find_by_sql(query)
            secure_result(Node, res) if res
          when :first
            res = klass.find_by_sql(query).first
            secure_result(Node, res) if res
          when :count
            klass.count_by_sql(query)
          else
            nil
          end
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
              puts err
              puts err.backtrace
            end
            do_find(count, eval(query.to_s))
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
        # Return the name of the group used for custom queries
        def query_group
          visitor.site.host
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
              table_to_use = main_table
            end
            "#{table_to_use}.#{map_def[:key]}"
          elsif %w{id parent_id project_id section_id}.include?(field_name) ||
            (Node.safe_method_type([field_name]) && Node.column_names.include?(field_name))
            "#{table}.#{field_name}"
          elsif @query.tables.include?('links') &&
               (key = field_name[/^l_(.+)$/,1]) &&
               (key == 'id' ||
                Zena::Use::Relations::LINK_ATTRIBUTES.include?(key.to_sym))
            "#{table('links')}.#{key}"
          else
          #elsif field_name == 'REF_DATE'
          #  context[:ref_date] ? insert_bind(context[:ref_date]) : 'now()'
          #else
            super # raises an error
          end
        end

        # Handle special case for 'class = '
        def process_equal(left, right)
          if left == [:field, 'class'] && right[0] == :field
            if klass = Node.get_class(right[1])
              "#{field_or_attr('kpath')} = #{quote(klass.kpath)}"
            else
              raise QueryBuilder::QueryException.new("Unknown class #{right.last.inspect}.")
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
            super
          end
        end

        def process_function(arg, method)
          arg, method = process(arg), process(method)
          Zena::Db.sql_function(method, arg)
        end

        # ******** And maybe overwrite these **********
        def parse_custom_query_argument(key, value)
          return nil unless value
          super(key, value.gsub('REF_DATE', context[:ref_date] ? insert_bind(context[:ref_date]) : 'now()'))
        end

        # Special case 'in site' that is a noop scope and
        # just avoids the insertion of the default 'in parent' scope.
        def need_join_scope?(scope_name)
          scope_name != 'site'
        end

        private
          # Change class
          def class_relation(relation)
            case relation
            when 'users'
              change_processor 'UserProcessor'
              add_table('users')
              add_filter "#{table('users')}.node_id = #{field_or_attr('id', table(self.class.main_table))}"
              return true
            else
              return nil
            end
          end

          # Moving to another context without a join table
          def context_relation(relation)
            # Not sure we need all these anymore...
            #case relation
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
            #when 'root'
            #  # Special pseudo-context
            #  @where << "#{table}.id = #{current_site.root_id}"
            #  return true
            #when 'author', 'traductions', 'versions'
            #  # TODO: not implemented yet...
            #  return nil
            #when 'visitor'
            #  # Special pseudo-context
            #  @where << "#{table}.id = #{insert_bind("visitor.contact_id")}"
            #  return true
            #end

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
                if klass.kind_of?(Class)
                  res_class = Class.new(klass)
                else
                  res_class = Class.new(klass.real_class)
                  res_class.kpath = klass.kpath
                end

                res_class.load_roles!
                set_main_class(res_class)

                add_table(main_table)
                add_filter "#{table}.kpath LIKE #{quote("#{klass.kpath}%")}"
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

              # source --> target
              if context[:scope] == 'site'
                # Example: 'tagged in site' ==> any node with a 'tagged' relation (no need to
                # filter by source).
                add_filter "#{field_or_attr('id')} = #{table('links')}.#{rel.other_side} AND #{table('links')}.relation_id = #{rel.id}"
              else
                add_filter "#{field_or_attr('id')} = #{table('links')}.#{rel.other_side} AND #{table('links')}.relation_id = #{rel.id} AND #{table('links')}.#{rel.link_side} = #{field_or_attr('id', table(main_table,-1))}"
              end
            else
              nil
            end
          end

          def secure_query
            query.add_filter "\#{secure_scope('#{table}')}"
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

          def merge_queries(query1, query2)
            if query1.tables.include?('links') && !query2.tables.include?('links')
              add_dummy_link_clause(query2)
            elsif query2.tables.include?('links') && !query1.tables.include?('links')
              add_dummy_link_clause(query1)
            end
            super
          end

          def process_or(left, right)
            left_clause  = [this.process(left)]
            right_clause = [this.process(right)]
            @query.tables.each do |t|
              if t =~ /^links AS (.+)$/
                lname = $1
              else
                lname = t
              end

              if left_clause =~ /#{lname}\./ && !right_clause =~ /#{lname}\./
                right_clause << "#{lname}.id = 0)"
              elsif right_clause =~ /#{lname}\./ && !left_clause =~ /#{lname}\./
                left_clause << "#{lname}.id = 0)"
              end
            end

            if left_clause.size > 1
              left_clause = "(#{left_clause.join(' AND ')})"
            else
              left_clause = left_clause.first
            end

            if right_clause.size > 1
              right_clause = "(#{right_clause.join(' AND ')})"
            else
              right_clause = right_clause.first
            end

            "(#{left_clause} OR #{right_clause})"
          end

          # This is used to avoid finding random links in clauses with and without link filters
          # like this: "image or icon" ('image' is a filter in 'parent' scope, 'icon' is a
          # relation found through links).
          def add_dummy_link_clause(query)
            query.where.insert(0, 'links.id = 0')
          end

          def node_name
            @context[:node_name]
          end
      end # Compiler
    end # QueryNode
  end # Use
end # Zena

