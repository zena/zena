module ParserTags
  module Zafu
    class << self
      def expose_methods(*args)
        args.each do |name|
          class_eval <<-END
            def r_#{name}
              helper.#{name}(@params)
            end
          END
        end
      end
    end
    expose_methods :uses_calendar, :lang_links, :login_link, :visitor_link, :search_box, :menu
    def r_show
      return unless check_params(:attr)
      attribute = @params[:attr]
      attribute = attribute[1..-1] if attribute[0..0] == ':'
      case attribute[0..1]
      when 'v_'
        "<%= #{node}.send(:version)[:#{attribute[2..-1]}] %>"
      when 'c_'
        "<%= #{node}.send(:version).content[:#{attribute[2..-1]}] %>"
      else
        "<%= #{node}[:#{attribute}] %>"
      end
    end

    def r_parent
      out "<% if #{var} = #{node}.parent -%>"
      out expand_with(:node=>var)
      out "<% end -%>"
    end
    
    def r_javascripts
      helper.javascript_include_tag(@params[:list])
    end
    
    def r_path_links
      helper.path_links(:node=>node)
    end
    
    def r_link
      helper.node_link(:href=>@params[:href], :node=>@context[:node], :text=>expand_with)
    end
    
    # <z:relation role='hot,project'> = get relation if empty get project
    # relation ? get ? role ? go ?
    
    # helpers
    # find the current node name in the context
    def node
      @context[:node] || '@node'
    end
    
    def list
      @context[:list]
    end
    
    def helper
      @options[:helper]
    end
  end
end
