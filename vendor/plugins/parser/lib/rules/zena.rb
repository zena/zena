module Zena
  module Tags
    class << self
      def inline_methods(*args)
        args.each do |name|
          class_eval <<-END
            def r_#{name}
              "<%= #{name}(:node=>\#{node}) %>"
            end
          END
        end
      end
      
      def direct_methods(*args)
        args.each do |name|
          class_eval <<-END
            def r_#{name}
              helper.#{name}
            end
          END
        end
      end
    end
    inline_methods :login_link, :visitor_link, :search_box, :menu, :path_links, :lang_links
    direct_methods :uses_calendar
    def r_show
      return unless check_params(:attr)
      attribute = @params[:attr]
      attribute = attribute[1..-1] if attribute[0..0] == ':'
      case attribute[0..1]
      when 'v_'
        "<%= #{node}.version[:#{attribute[2..-1]}] %>"
      when 'c_'
        "<%= #{node}.version.content[:#{attribute[2..-1]}] %>"
      else
        "<%= #{node}[:#{attribute}] %>"
      end
    end
    
    # convenience tag. Does the same as <z:show attr='v_title'/>
    def r_title
      "<%= #{node}.version[:title] %>"
    end

    def r_parent
      out "<% if #{var} = #{node}.parent -%>"
      out expand_with(:node=>var)
      out "<% end -%>"
    end
    
    # we cannot directly render this (running in controller, not in view...)
    def r_javascripts
      list = @params[:list].split(',').map{|e| e.strip}
      helper.javascript_include_tag(*list)
    end
    
    # we cannot directly render this (running in controller, not in view...)
    def r_stylesheets
      list = @params[:list].split(',').map{|e| e.strip}
      helper.stylesheet_link_tag(*list)
    end
    
    def r_flash_messages
      type = @params[:show] || 'both'
      "<div id='messages'>" +
      if (type == 'notice' || type == 'both')
        "<% if @flash[:notice] -%><div id='notice' class='flash' onClick='new Effect.Fade(\"error\")'><%= @flash[:notice] %></div><% end -%>"
      else
        ''
      end + 
      if (type == 'error'  || type == 'both')
        "<% if @flash[:error] -%><div id='error' class='flash' onClick='new Effect.Fade(\"error\")'><%= @flash[:error] %></div><% end -%>"
      else
        ''
      end +
      "</div>"
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
