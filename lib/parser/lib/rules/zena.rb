module Zena
  module Rules
  end
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
      return "" unless check_params(:attr)
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
      out "<div id='v_text<%= #{node}.version[:id] %>' class='zazen'>"
      unless @params[:empty] == 'true'
        out "<% if #{node}.kind_of?(TextDocument); l = #{node}.content_lang -%>"
        out "<%= zazen(\"<code\#{l ? \" lang='\#{l}'\" : ''} class=\\'full\\'>\#{#{node}.version.text}</code>\") %></div>"
        out "<% else -%>"
        out "<%= zazen(#{node}.version[:text]) %>"
        out "<% end -%>"
      end
      out "</div>"
    end
    
    def r_summary
      # if opt[:as]
      #   key = "#{opt[:as]}#{obj.v_id}"
      #   preview_for = opt[:as]
      #   opt.delete(:as)
      # else
      #   key = "#{sym}#{obj.v_id}"
      # end
      # if opt[:text]
      #   text = opt[:text]
      #   opt.delete(:text)
      # else
      #   text = obj.send(sym)
      #   if (text.nil? || text == '') && sym == :v_summary
      #     text = obj.v_text
      #     opt[:images] = false
      #   else
      #     opt.delete(:limit)
      #   end
      # end
      # if [:v_text, :v_summary].include?(sym)
      #   if obj.kind_of?(TextDocument) && sym == :v_text
      #     lang = obj.content_lang
      #     lang = lang ? " lang='#{lang}'" : ""
      #     text = "<code#{lang} class='full'>#{text}</code>"
      #   end
      #   text  = zazen(text, opt)
      #   klass = " class='text'"
      # else
      #   klass = ""
      # end
      # if preview_for
      #   render_to_string :partial=>'node/show_attr', :locals=>{:id=>obj[:id], :text=>text, :preview_for=>preview_for, :key=>key, :klass=>klass,
      #                                                        :key_on=>"#{key}#{Time.now.to_i}_on", :key_off=>"#{key}#{Time.now.to_i}_off"}
      # else
      #   "<div id='#{key}'#{klass}>#{text}</div>"
      # end
    end
    
    def r_show_author
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
    
    # TODO: test
    def r_author
      return "" unless check_node_class(:Node, :Version, :Comment)
      out "<% if #{var} = #{node}.author -%>"
      out expand_with(:node=>var, :node_class=>:User)
      out "<% end -%>"
    end
    
    def r_edit
      if @context[:preflight]
        # preprocessing
        # we need forms/templates for ajax
        @pass[:edit] = self
        return ""
      end
      text = expand_with
      if @context[:each] && @context[:each] == @context[:node_class]
        # preprocessing
        # we need forms/templates for ajax
        @pass[:edit] = true
        return ""
      elsif @context[:template_url]
        # ajax
        "<%= link_to_function(#{text.inspect}, :controller=>'zafu', :action=>'ajax_edit', :id=>#{node}[:id], :template_url=>#{@context[:template_url].inspect}) %>"
      else
        "<%= link_to(#{text.inspect}, :controller=>'zafu', :action=>'edit', :id=>#{node}[:id], :template_url=>#{@context[:template_url].inspect}) %>" # FIXME
      end
    end
    
    def r_form
      if @context[:preflight]
        # preprocessing
        # we need forms/templates for ajax
        @pass[:form] = self
        return ""
      end
      if @context[:template_url]
        # ajax
        start = "<%= form_remote_tag(:url=>{:controller=>'Zafu', :action=>'ajax_form', :id=>(#{node} ? #{node}[:id] : '')}) %>"
        start << "<input type='hidden' name='template_url' value='#{@context[:template_url]}'/>"
      else
        # no ajax
        start = "<%= form_tag(:controller=>'Zafu', :action=>'form', :id=>(#{node} ? #{node}[:id] : '')) %>"
      end
      exp = expand_with
      if exp =~ /([^<]*)<(\w+)([^>]*)>(.*)<\/\2>(.*)/
        out $1
        tag   = $2
        inner = $4
        after = $5
        if @context[:tag_params]
          start_tag  = add_params("<#{$2}#{$3}>", @context[:tag_params])
        elsif @context[:template_url]
          start_tag  = add_params("<#{$2}#{$3}>", :id=>"#{@context[:template_url].gsub('/', '_')}<%= #{node}[:id] %>")
        else
          start_tag = "<#{$2}#{$3}>"
        end
        inner.gsub!(/<\/?form[^>]*>/,'')
        out "#{start_tag}#{start}#{inner}<%= end_form_tag -%></#{tag}>#{after}"
      else
        out start
        out exp
        out "<%= end_form_tag -%>"
      end
    end
    
    # TODO: test
    def r_add
      if @context[:preflight]
        # preprocessing
        # we need forms/templates for ajax
        @pass[:add] = self
        return ""
      end
      text = expand_with
      if @context[:form] && @context[:template_url]
        # ajax add
        prefix  = @context[:template_url].gsub('/','_')
        if @params[:tag]
          out "<#{@params[:tag]} id='#{prefix}<%= @#{node_class.to_s.downcase}[:id] %>'>"
        else
          text = add_params(text, :id=>"#{prefix}_add", :onclick=>"new Element.toggle('#{prefix}_add', '#{prefix}_form');return false;")
        end
        out text
        out expand_block(@context[:form],:node=>"@#{node_class.to_s.downcase}", :tag_params=>{:id=>"#{prefix}_form", :style=>"display:none;"})
        if @params[:tag]
          out "</#{@params[:tag]}>"
        end
      else
        # no ajax
        "<%= link_to(#{text.inspect}, ...) %>" # FIXME
      end
    end
 
    def r_each
      if @context[:preflight]
        expand_with(:preflight=>true)
        @pass[:each] = self
      elsif @context[:list]
        out "<% #{list}.each do |#{var}| -%>"
        res = expand_with(:node=>var)
        if @context[:template_url]
          # ajax, set id
          res = add_params(res, :id=>"#{@context[:template_url].gsub('/', '_')}<%= #{var}[:id] %>")
        end
        out res
        out "<% end -%>"
      else  
        res = expand_with
        if @context[:template_url]
          # ajax, set id
          res = add_params(res, :id=>"#{@context[:template_url].gsub('/', '_')}<%= #{node}[:id] %>")
        end
      end
    end
   
    def r_case
      out "<% if false -%>"
      @blocks.each do |block|
        if block.kind_of?(self.class) && ['when', 'else'].include?(block.method)
          out block.render(@context.merge(:case=>true))
        else
          # drop
        end
      end
      out "<% end -%>"
    end
    
    def r_else
      return unless @context[:case]
      out "<% elsif true -%>"
      out expand_with(:case=>false)
    end
    
    def r_when
      return "<span class='zafu_error'>bad context for when clause</span>" unless @context[:case]
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
      out expand_with(:case=>false)
    end
    
    # be carefull, this gives a list of 'versions', not 'nodes'
    def r_traductions
      out "<% if #{list_var} = #{node}.traductions %>"
      out expand_with(:list=>list_var, :node_class=>:Version)
      out "<% end -%>"
    end
    
    def r_parent
      return unless check_node_class(:Node)
      out "<% if #{var} = #{node}.parent -%>"
      out expand_with(:node=>var, :node_class=>:Node)
      out "<% end -%>"
    end
    
    def r_children
      return unless check_node_class(:Node)
      do_list("#{node}.children")
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
    
    def var
      return @var if @var
      if node =~ /^var(\d+)$/
        @var = "var#{$1.to_i + 1}"
      else
        @var = "var1"
      end
    end
    
    def list_var
      return @list_var if @list_var
      if (list || "") =~ /^list(\d+)$/
        @list_var = "list#{$1.to_i + 1}"
      else
        @list_var = "list1"
      end
    end
    
    def node_class
      @context[:node_class] || :Node
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
    
    def do_list(list_finder)
      out "<% if #{list_var} = #{list_finder} -%>"
      @context.delete(:template_url) # should not propagate
      
      # preflight parse to see what we have
      expand_with(:preflight=>true)
      
      if (form_block = @pass[:form]) && (each_block = @pass[:each]) && (@pass[:edit] || @pass[:add])
        # ajax
        template_url  = "#{@options[:current_folder]}/#{@context[:name] || "root"}_#{node_class}"
        
        # render without 'add' or 'form'
        out expand_with(:list=>list_var, :no_add=>true, :no_form=>true, :template_url=>template_url)
        out "<% end -%>"
        
        # render add
        if add_block = @pass[:add]
          out expand_block(add_block, :node=>"@#{node_class.to_s.downcase}",
                                                    :form=>form_block,
                                                    :template_url=>template_url)
        end

        # TEMPLATE ========
        template_node = "@#{node_class.to_s.downcase}"
        template      = expand_block(each_block, :node=>template_node, :template_url=>template_url, :list=>false)
        out helper.save_erb_to_url(template, template_url)
        
        # FORM ============
        form_url     = "#{template_url}_form"
        form = expand_block(form_block, :node=>"@#{node_class.to_s.downcase}", :template_url=>template_url, :tag_params=>{:id=>"<%= @id %>"})
        out helper.save_erb_to_url(form, form_url)
      else
        # no form, render, edit and add are not ajax
        out expand_with(:list=>list_var)
        out "<% end -%>"
      end
      @pass = {} # do not propagate back
    end
       
    def add_params(text, opts={})
      text.sub(/\A([^<]*)<(\w+)( [^>]+|)>/) do
        # we must set the first tag id
        before = $1
        tag = $2
        params = parse_params($3)
        opts.each do |k,v|
          params[k] = v
        end
        para = ""
        params.each do |k,v|
          para << " #{k}=#{params[k].inspect.gsub("'","TMPQUOTE").gsub('"',"'").gsub("TMPQUOTE",'"')}"
        end
        "#{before}<#{tag}#{para}>"
      end
    end
    
    # TODO: test
    def check_node_class(*list)
      list.include?(node_class)
    end
  end
end
