module Zena
  module Use
    module QueryNodeFinders
      module AddUseQueryNodeMethod
        def self.included(base)
          # create class methods
          base.extend AddUseQueryNodeMethodImpl
        end
      end

      module AddUseQueryNodeMethodImpl
        def use_node_query
          class_eval do
            include Zena::Use::QueryNodeFinders::InstanceMethods
            class << self
              include Zena::Use::QueryNodeFinders::ClassMethods
            end
          end
        end
      end

      module ClassMethods

        # Return an sql query string that will be used by 'do_find':
        # build_find(:all, PSEUDO_SQL, node_name) => "SELECT * FROM nodes WHERE nodes.parent_id = #{@node[:id]} AND ..."
        # PSEUDO_SQL: what to find in pseudo sql (See QueryNode for details).
        # node_name: contextual variable name
        #
        # Pseudo sql syntax:
        #
        # '[CLASS|VCLASS|RELATION] [in [site|section|project|parent]|] [where CLAUSE|] [from SUB_QUERY|] or [PSEUDO_SQL]'
        #
        # with :
        #   * CLASS:  a native class ('images', 'documents', 'pages', 'projects', ...)
        #   * VCLASS: a virtual class created by the user ('posts', 'houses', ...)
        #   * RELATION: a relation defined by the user ('icon_for', 'news', 'calendar', ...)
        #   * CLAUSE: field = value ('log_at:year = 2005'). You can use parameters, visitor data in clause: 'log_at:year = [param:year]', 'd_assigned = [visitor:name]'. You can only use 'and' in clauses. 'or' is not supported. You can use version and/or dynamic attributes : 'v_comment = super', 'd_priority = low'.
        #
        # Examples: 'todos in section where d_priority = high and d_assigned = [visitor:name]'
        #def build_find(count, pseudo_sql, node_name, raw_filters = nil, ignore_warnings = false, ref_date = nil)
        def build_find(count, pseudo_sql, opts = {})
          if count == :first
            opts[:limit] = 1
          end
          Zena::Use::QueryNode.new(pseudo_sql, opts.merge(:custom_query_group => visitor.site.host))
        end
      end # ClassMethods


      module InstanceMethods

        # Find a node and propagate visitor
        def do_find(count, query, ignore_source = false, klass = Node)
          return nil if query.empty?
          return nil if (new_record? && !ignore_source) # do not run query (might contain nil id)

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
        # TODO: replace with rubyless translate ? Is this thing really used anyway ?
        def find(count, rel, opts = {})
          rel = [rel] if rel.kind_of?(String)

          if !opts[:skip_rubyless] && rel.size == 1 && type = RubyLess::SafeClass.safe_method_type_for(self.class, [rel.first])
            self.send(type[:method])
          else
            query = Node.build_find(count, rel, :node_name => 'self')
            if query.valid?
              do_find(count, eval(query.to_s))
            else
              nil
            end
          end
        end
      end # InstanceMethods
    end # QueryNodeFinders
  end # Use
end # Zena