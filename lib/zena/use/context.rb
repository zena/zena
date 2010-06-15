module Zena
  module Use
    module Context
      module ViewMethods
        include RubyLess
        safe_method :start => {:method => 'start_node', :class => Node}
        safe_method :visitor => User
        safe_method :visitor_node => {:method => 'visitor.contact', :class => BaseContact, :nil => true}
        safe_method :main => {:method => '@node', :class => Node}
        safe_method :root => {:method => 'visitor.site.root_node', :class => Node, :nil => true}
        safe_method :site => {:class => Site, :method => 'visitor.site'}

        # Group an array of records by key.
        def group_array(list)
          groups = []
          h = {}
          list.each do |e|
            key = yield(e)
            unless group_id = h[key]
              h[key] = group_id = groups.size
              groups << []
            end
            groups[group_id] << e
          end
          groups
        end

        def sort_array(list)
          list.sort do |a,b|
            va = yield([a].flatten[0])
            vb = yield([b].flatten[0])
            if va && vb
              va <=> vb
            elsif va
              1
            elsif vb
              -1
            else
              0
            end
          end
        end

        def min_array(list)
          list.flatten.min do |a,b|
            va = yield(a)
            vb = yield(b)
            if va && vb
              va <=> vb
            elsif va
              1
            elsif vb
              -1
            else
              0
            end
          end
        end

        def max_array(list)
          list.flatten.min do |a,b|
            va = yield(a)
            vb = yield(b)
            if va && vb
              vb <=> va
            elsif vb
              1
            elsif va
              -1
            else
              0
            end
          end
        end

        # main node before ajax stuff (the one in browser url)
        def start_node
          @start_node ||= if params[:s]
            secure(Node) { Node.find_by_zip(params[:s]) }
          else
            @node
          end
        end

        # Enter page numbers context.
        #
        # ==== Parameters
        #
        # * +current+     - current page number
        # * +count+       - total number of pages
        # * +join_string+ - (optional) string to use to join page numbers
        # * +max_count+   - (optional) maximum number of pages to display
        # * +&block+      - block to yield for each page number. Receives |page_number, join_string|.
        def page_numbers(current, count, join_string = nil, max_count = nil)
          max_count ||= 10
          join_string ||= ''
          join_str = ''
          if count <= max_count
            1.upto(count) do |p|
              yield(p, join_str)
              join_str = join_string
            end
          else
            # only first pages (centered around current page)
            if current - (max_count/2) > 0
              finish = [current + (max_count/2),count].min
            else
              finish = [max_count,count].min
            end

            start  = [finish - max_count + 1,1].max

            start.upto(finish) do |p|
              yield(p, join_str)
              join_str = join_string
            end
          end
        end
      end # ViewMethods

      module ZafuMethods

        # Enter a new context (<r:context find='all' select='pages'>). This is the same as '<r:pages>...</r:pages>'). It is
        # considered better style to use '<r:pages>...</r:pages>' instead of the more general '<r:context>' because the tags
        # give a clue on the context at start and end. Another way to open a context is the 'do' syntax: "<div do='pages'>...</div>".
        def r_context
          return parser_error("missing 'select' parameter") unless method = @params[:select]
          querybuilder_eval(method)
        end

        alias r_find r_context

        # Group elements in a list. Use :order to specify order.
        def r_group
          return parser_error("cannot be used outside of a list") unless node.list_context?
          return parser_error("missing 'by' clause") unless key = @params[:by]

          #sort_key = @params[:sort] || 'node_name'
          # if node.will_be?(DataEntry) && DataEntry::NodeLinkSymbols.include?(key.to_sym)
          #   key = "#{key}_id"
          #   #sort_block = "{|e| (e.#{key} || {})[#{sort_key.to_sym.inspect}]}"
          #   group_array = "group_array(#{node}) {|e| e.#{key}}"
          # elsif node.will_be?(Node)
          #   if ['project', 'parent', 'section'].include?(key)
          #     #sort_block  = "{|e| (e.#{key} || {})[#{sort_key.to_sym.inspect}]}"
          #     group_array = "group_array(#{node}) {|e| e.#{key}_id}"
          #   end
          # end

          if %w{parent project section}.include?(key)
            key = "e.#{key}"
          else
            key = "e.#{RubyLess.translate(key, node.klass.first)}"
          end

          #if sort_block
          #  out "<% grp_#{list_var} = sort_array(#{group_array}) #{sort_block} -%>"
          #else
            out "<% #{var} = group_array(#{node}) {|e| #{key}} -%>"
          #end

          if descendant('each_group')
            out expand_with(:group => var)
          else
            @context[:group] = var
            r_each_group
          end
        end


        def r_each_group
          return parser_error("must be used inside a group context") unless group = @context[:group]
          if join = @params[:join]
            join = join.gsub(/&lt;([^%])/, '<\1').gsub(/([^%])&gt;/, '\1>')
            out "<% #{group}.each_with_index do |#{var}, #{var}_i| -%>"
            out "<%= #{var}_i > 0 ? #{join.inspect} : '' %>"
          else
            out "<% #{group}.each do |#{var}| -%>"
          end

          out wrap(expand_with(:group => nil, :node => node.move_to(var, node.klass)))
          out "<% end -%>"
        end
      end # ZafuMethods
    end # Context
  end # Use
end # Zena