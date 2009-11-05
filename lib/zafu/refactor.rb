module Zafu
  module Refactor
    def r_node
      @method = @params[:select] || 'node' # 'node' is for version.node
      r_unknown
    end

    def base_class
      if node_kind_of?(Node)
        Node
      elsif node_kind_of?(Version)
        Version
      else
        node_class
      end
    end

    # get current output format
    def output_format
      @context[:output_format] || 'html'
    end

    # icon or first image (defined using build_finder_for instead of zafu_known_context for performance reasons).
    def r_icon
      if !@params[:in] && !@params[:where] && !@params[:from] && !@params[:find]
        finder, klass = build_finder_for(:first, 'icon', @params.merge(:or => 'image', :order => 'l_id desc, position asc, name asc', :group => 'id,l_id'))
        return unless finder
        return parser_error("invalid class (#{klass})") unless klass.ancestors.include?(Node)
        do_var(finder, :node_class => klass)
      else
        r_unknown
      end
    end

    # be carefull, this gives a list of 'versions', not 'nodes'
    def r_traductions
      if @params[:except]
        case @params[:except]
        when 'current'
          opts = "(:conditions=>\"lang != '#{helper.lang}'\")"
        else
          # list of lang
          # TODO: test
          langs = @params[:except].split(',').map{|l| l.gsub(/[^a-z]/,'').strip }
          opts = "(:conditions=>\"lang NOT IN ('#{langs.join("','")}')\")"
        end
      elsif @params[:only]
        # TODO: test
        case @params[:only]
        when 'current'
          opts = "(:conditions=>\"lang = '#{helper.lang}'\")"
        else
          # list of lang
          # TODO: test
          langs = @params[:only].split(',').map{|l| l.gsub(/[^a-z]/,'').strip }
          opts = "(:conditions=>\"lang IN ('#{langs.join("','")}')\")"
        end
      else
        opts = ""
      end
      out "<% if #{list_var} = #{node}.traductions#{opts} -%>"
      out expand_with(:list=>list_var, :node_class => Version)
      out "<% end -%>"
    end

    # TODO: test
    def r_show_traductions
      "<% if #{list_var} = #{node}.traductions -%>"
      "#{_("Traductions:")} <span class='traductions'><%= #{list_var}.join(', ') %></span>"
      "<%= traductions(:node=>#{node}).join(', ') %>"
    end
  end # Refactor
end # Zafu