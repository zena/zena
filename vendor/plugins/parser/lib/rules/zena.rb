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
    
    def r_title
      res = "<%= show_title(:node=>#{node}"
      unless @params.include?(:link)
        res << ", :link=>#{@params[:link] == 'true'}"
      end
      unless @params.include?(:project)
        res << ", :project=>#{@params[:project] == 'true'}"
      end
      res << ")"
      if @params[:actions]
        res << " + node_actions(:node=>#{node}, #{erb_param(:actions)})"
      end
      res << "%>"
      if @params[:status]
        res = "<div class='s<%= #{node}.version.status %>'>#{res}</div>"
      end
      res
    end
    
    def r_text
      
    end
    
    def r_author
      if @params[:size] == 'large'
        out "#{helper.trans("posted by")} <b><%= #{node}.author.fullname %></b>"
        out "<% if #{node}[:user_id] != #{node}.version[:user_id] -%>"
        out "<% if #{node}[:ref_lang] != #{node}.version[:lang] -%>"
        out "#{helper.trans("traduction by")} <b><%= #{node}.version.author.fullname %></b>"
        out "<% else -%>"
        out "#{helper.trans("modified by")} <b><%= #{node}.version.author.fullname %></b>"
        out "<% end"
        out "   end -%>"
        out " #{helper.trans("on")} <%= format_date(#{node}.version.updated_at, #{helper.trans('short_date').inspect}) %>."
        if @params[:traductions] == 'true'
          out " #{helper.trans("Traductions")} : <span class='traductions'><%= helper.traductions(:node=>#{node}).join(', ') %></span>"
        end
      else
        out "<b><%= #{node}.version.author.initials %></b> - <%= format_date(#{node}.version.updated_at, #{helper.trans('short_date').inspect}) %>"
        if @params[:traductions] == 'true'
          out " <span class='traductions'>(<%= helper.traductions(:node=>#{node}).join(', ') %>)</span>"
        end
      end
    end
    
    def r_each
      out "<% (#{list} || []).each do |#{var}| -%>"
      out expand_with(:node=>var)
      out "<% end -%>"
    end
    
    def r_case
      out "<% if false -%>"
      @blocks.each do |block|
        if block.kind_of?(self.class) && ['when', 'else'].include?(block.method)
          out block.render(@context.merge(:choose=>true))
        else
          # drop
        end
      end
      out "<% end -%>"
    end
    
    def r_else
      return unless @context[:choose]
      out "<% elsif true -%>"
      out expand_with(:choose=>false)
    end
    
    def r_when
      return "<span class='zafu_error'>bad context for when clause</span>" unless @context[:choose]
      if klass = @params[:kind_of]
        begin Module::const_get(klass) rescue "NilClass" end
        cond = "#{node}.kind_of?(#{klass})"
      elsif klass = (@params[:klass] || @params[:class])
        begin Module::const_get(klass) rescue "NilClass" end
        cond = "#{node}.class == #{klass}"
      elsif status = @params[:status]
        cond = "#{node}.version[:status] == #{Zena::Status[status.to_sym]}"
      elsif lang = @params[:lang]
        cond = "#{node}.version[:lang] == #{lang.inspect}"
      else
        cond = nil
      end
      return "<span class='zafu_error'>condition error for when clause</span>" unless cond
      out "<% elsif #{cond} -%>"
      out expand_with(:choose=>false)
    end
    
    # be carefull, this gives a list of 'versions', not 'nodes'
    def r_traductions
      out "<% if #{var} = #{node}.traductions %>"
      out expand_with(:list=>var)
      out "<% end -%>"
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
    
    def erb_param(param)
      if @params[param]
        "#{param.inspect}=>#{@params[param].strip.inspect}"
      else
        ""
      end
    end
  end
end
