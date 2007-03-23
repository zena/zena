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
    inline_methods :login_link, :visitor_link, :search_box, :show_menu, :show_comments, :show_path, :lang_links
    direct_methods :uses_calendar

    def before_render
      if @params[:store]
        @context["stored_#{@params[:store]}".to_sym] = node
        @params.delete(:store)
      end
      if @params[:anchor] && !@context[:preflight]
        @anchor = r_anchor
        @params.delete(:anchor)
      end
      true
    end
    
    def after_render(text)
      if @anchor
        @anchor + text
      else
        text
      end
    end

    def r_show
      attribute = @params[:attr] || @params[:tattr]
      if @context[:trans]
        # TODO: what do we do here with dates ?
        "#{node}#{get_attribute(attribute)}"
      elsif @params[:tattr]
        "<%= trans(#{node}#{get_attribute(attribute)}) %>"
      elsif @params[:attr]
        "<%= #{node}#{get_attribute(attribute)} %>"
      elsif @params[:date]
        # date can be any attribute v_created_at or updated_at etc.
        # TODO format with @params[:format] and @params[:tformat] << translated format
      else
        # error
      end
    end
    
    def r_zazen
      attribute = @params[:attr] || @params[:tattr]
      if @context[:trans]
        # TODO: what do we do here with dates ?
        "#{node}#{get_attribute(attribute)}"
      elsif @params[:tattr]
        "<%= zazen(trans(#{node}#{get_attribute(attribute)})) %>"
      elsif @params[:attr]
        "<%= zazen(#{node}#{get_attribute(attribute)}) %>"
      elsif @params[:date]
        # date can be any attribute v_created_at or updated_at etc.
        # TODO format with @params[:format] and @params[:tformat] << translated format
      else
        # error
      end
    end
    
    def r_trans
      static = true
      if @params[:text]
        text = @params[:text]
      elsif @params[:attr]
        text = "#{node}#{get_attribute(@params[:attr])}"
        static = false
      else
        res  = []
        text = ""
        @blocks.each do |b|
          if b.kind_of?(String)
            res  << b.inspect
            text << b
          elsif ['show'].include?(b.method)
            res << expand_block(b, :trans=>true)
            static = false
          else
            # ignore
          end
        end
        unless static
          text = res.join(' + ')
        end
      end
      if static
        helper.trans(text)
      else
        "<%= trans(#{text}) %>"
      end
    end
    
    def r_anchor(obj=node)
      "<a name='#{node_class.to_s.downcase}<%= #{obj}[:id] %>'></a>"
    end
    
    def r_content_for_layout
      "<% if @content_for_layout -%><%= @content_for_layout %><% else -%>" +
      expand_with +
      "<% end -%>"
    end
    
    def r_title_for_layout
      "<% if @title_for_layout -%><%= @title_for_layout %><% else -%>" +
      expand_with +
      "<% end -%>"
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
        res << " + node_actions(:node=>#{node}#{params_to_erb(:actions=>@params[:actions])})"
      end
      res << "%>"
      if @params[:status] == 'true' || (@params[:status].nil? && @params[:actions])
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
      @pass[:edit] = self
      if @context[:preflight]
        # preprocessing
        return ""
      end
      text = get_text_for_erb
      if @context[:template_url]
        # ajax
        "<%= link_to_remote(#{text || helper.trans('edit')}, :url=>{:controller=>'zafu', :action=>'ajax_edit', :id=>#{node}[:id], :template_url=>#{@context[:template_url].inspect}}) %>"
      else
        "<%= link_to(#{text || helper.trans('edit')}, :controller=>'zafu', :action=>'edit', :id=>#{node}[:id], :template_url=>#{@context[:template_url].inspect}) %>"
      end
    end
    
    # TODO: add parent_id into the form !
    def r_form
      @pass[:form] = self
      if @context[:preflight]
        # preprocessing
        return ""
      end
      if @context[:template_url]
        # ajax
        start = "<%= form_remote_tag(:url=>{:controller=>'zafu', :action=>'ajax_form', :id=>(#{node} ? #{node}[:id] : '')}) %>"
        start << "<input type='hidden' name='template_url' value='#{@context[:template_url]}'/>"
      else
        # no ajax
        start = "<%= form_tag(:controller=>'zafu', :action=>'form', :id=>(#{node} ? #{node}[:id] : '')) %>"
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
      @pass[:add] = self
      if @context[:preflight]
        # preprocessing
        return ""
      end
      if @params[:text]
        text = @params[:text]
        text = "<div>#{text}</div>" unless @html_tag
      elsif @params[:trans]
        text = helper.trans(@params[:trans])
        text = "<div>#{text}</div>" unless @html_tag
      else
        text = expand_with
      end
      if @context[:form] && @context[:template_url]
        # ajax add
        prefix  = @context[:template_url].gsub('/','_')
        if @html_tag
          out "<#{@html_tag} id='#{prefix}<%= @#{node_class.to_s.downcase}[:id] %>'>"
        else
          text = add_params(text, :id=>"#{prefix}_add", :onclick=>"new Element.toggle('#{prefix}_add', '#{prefix}_form');return false;")
        end
        out text
        out expand_block(@context[:form],:node=>"@#{node_class.to_s.downcase}", :tag_params=>{:id=>"#{prefix}_form", :style=>"display:none;"})
        if @html_tag
          out "</#{@html_tag}>"
        end
      else
        # no ajax
        "<%= link_to(#{text.inspect}, ...) %>" # FIXME
      end
    end
    
    #if RAILS_ENV == 'test'
    #  def r_test
    #    inspect
    #  end
    #end
 
    def r_each
      if @context[:preflight]
        expand_with(:preflight=>true)
        @pass[:each] = self
      elsif @context[:list]
        if join = @params[:join]
          join = join.gsub(/&lt;([^%])/, '<\1').gsub(/([^%])&gt;/, '\1>')
          out "<% #{list}.each_index do |#{var}_index| -%>"
          out "<%= #{var}=#{list}[#{var}_index]; #{var}_index > 0 ? #{join.inspect} : '' %>"
        else
          out "<% #{list}.each do |#{var}| -%>"
        end
        out r_anchor(var) if @anchor # insert anchor inside the each loop
        @anchor = nil
        res = expand_with(:node=>var)
        if @context[:template_url] && @pass[:edit]
          # ajax, set id
          id_hash = {:id=>"#{@context[:template_url].gsub('/', '_')}<%= #{var}[:id] %>"}
          if @html_tag
            @html_tag_params.merge!(id_hash)
          else
            res = add_params(res, :id=>"#{@context[:template_url].gsub('/', '_')}<%= #{var}[:id] %>")
          end
        end
        res = render_html_tag(res)
        out res
        out "<% end -%>"
      else
        res = expand_with
        if @context[:template_url] && @pass[:edit]
          # ajax, set id
          res = add_params(res, :id=>"#{@context[:template_url].gsub('/', '_')}<%= #{node}[:id] %>")
        end
        res
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
      if @context[:preflight]
        @pass[:else] = self
        return
      end
      if @context[:case]
        out "<% elsif true -%>"
        out expand_with(:case=>false)
      elsif @context[:do]
        out expand_with(:do=>false)
      else
        ""
      end
    end
    
    def r_when
      return "<span class='parser_error'>bad context for when clause</span>" unless @context[:case]
      if klass = @params[:kind_of]
        begin Module::const_get(klass) rescue "NilClass" end
        cond = "#{node}.kind_of?(#{klass})"
      elsif klass = @params[:klass]
        begin Module::const_get(klass) rescue "NilClass" end
        cond = "#{node}.class == #{klass}"
      elsif status = @params[:status]
        cond = "#{node}.version[:status] == #{Zena::Status[status.to_sym]}"
      elsif lang = @params[:lang]
        cond = "#{node}.version[:lang] == #{lang.inspect}"
      elsif node_cond = @params[:node]
        if node_kind_of?(Node)
          case node_cond
          when 'self'
            cond = "#{node}[:id] == @node[:id]"
          when 'parent'
            cond = "#{node}[:id] == @node[:parent_id]"
          when 'project'
            cond = "#{node}[:id] == @node[:project_id]"
          when 'ancestor'
            cond = "@node.fullpath =~ /\\A\#{#{node}.fullpath}/"
          else
            cond = nil
          end
        else
          cond = nil
        end
      else
        cond = nil
      end
      return "<span class='parser_error'>condition error for when clause</span>" unless cond
      out "<% elsif #{cond} -%>"
      out expand_with(:case=>false)
    end
    
    # be carefull, this gives a list of 'versions', not 'nodes'
    def r_traductions
      out "<% if #{list_var} = #{node}.traductions -%>"
      out expand_with(:list=>list_var, :node_class=>:Version)
      out "<% end -%>"
    end
    
    # TODO: test
    def r_show_traductions
      "<% if #{list_var} = #{node}.traductions -%>"
      "#{helper.trans("Traductions:")} <span class='traductions'><%= #{list_var}.join(', ') %></span>"
      "<%= traductions(:node=>#{node}).join(', ') %>"
    end
    
    def r_node
      select = @params[:select]
      if select == 'main'
        do_var("@node")
      elsif select == 'root'
        do_var("secure(Node) { Node.find(#{ZENA_ENV[:root_id]})} rescue nil")
      elsif select == 'stored'
        if stored = @context[:stored_node]
          do_var(stored)
        else
          "<span class='parser_error'>No stored nodes in the current context</span>"
        end
      elsif select == 'visitor'
        do_var("visitor.contact")
      elsif select =~ /^\d+$/
        do_var("secure(Node) { Node.find_by_id(#{select.inspect})} rescue nil")
      else
        select = select[1..-1] if select[0..0] == '/'
        do_var("secure(Node) { Node.find_by_path(#{select.inspect})} rescue nil")
      end
    end
    
    def r_date
      select = @params[:select]
      case select
      when 'main'
        expand_with(:date=>'#{main_date.strftime("%Y-%m-%d")}')
      when 'now'
        expand_with(:date=>'#{Time.now.strftime("%Y-%m-%d")}')
      when 'stored'
        if stored = @context[:stored_date]
          expand_with(:date=>stored)
        else
          "<span class='parser_error'>No stored date in the current context</span>"
        end
      else
        if select =~ /^\d{4}-\d{1,2}-\d{1,2}$/
          expand_with(:date=>select)
        else
          "<span class='parser_error'>Bad parameter for 'date' should be (main,now,stored)</span>"
        end
      end
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
        "<% if @flash[:notice] -%><div id='notice' class='flash' onclick='new Effect.Fade(\"error\")'><%= @flash[:notice] %></div><% end -%>"
      else
        ''
      end + 
      if (type == 'error'  || type == 'both')
        "<% if @flash[:error] -%><div id='error' class='flash' onclick='new Effect.Fade(\"error\")'><%= @flash[:error] %></div><% end -%>"
      else
        ''
      end +
      "</div>"
    end
    
    
    # creates a link. Options are:
    # :href (node, parent, project, root)
    # :tattr (translated attribute used as text link)
    # :attr (attribute used as text link)
    # <z:link href='node'><z:trans attr='lang'/></z:link>
    # <z:link href='node' tattr='lang'/>
    def r_link
      # text
      @blocks = [] # do not use block content for link.
      text = get_text_for_erb
      if text
        text = ", :text=>#{text}"
      else
        text = ""
      end
      if @params[:href]
        href = ", :href=>#{@params[:href].inspect}"
      else
        href = ''
      end
      # obj
      if node_class == :Version
        lnode = "#{node}.node"
        url = ", :url=>{:lang=>#{node}[:lang]}"
      else
        lnode = node
        url = ''
      end
      if @params[:dash] == 'true'
        dash = ", :dash=>\"#{node_class.to_s.downcase}\#{#{node}[:id]}\""
      else
        dash = ''
      end
      # link
      "<%= node_link(:node=>#{lnode}#{text}#{href}#{url}#{dash}) %>"
    end
    
    def r_img
      return unless check_node_class(:Node)
      if @params[:src]
        img = "#{node}.relation(#{@params[:src].inspect})"
      else
        img = node
      end
      format = @params[:format] || 'std'
      if @params[:href]
        "<%= node_link(:node=>#{node}, :href=>#{@params[:href].inspect}, :text=>#{img}.img_tag(#{format.inspect})) rescue '' %>"
      else
        "<%= #{img}.img_tag(#{format.inspect}) rescue '' %>"
      end
    end
    
    def r_ignore
      @html_tag_done = true
      ""
    end
    
    # use all other tags as relations
    # try to add 'conditions' without sql injection possibilities...
    def r_unknown
      return '' if @context[:preflight]
      "not a node (#{@method})" unless node_kind_of?(Node)
      rel = @method
      if @params[:else]
        rel = [@method] + @params[:else].split(',').map{|e| e.strip}
        rel = rel.join(',')
      else
        rel = @method
      end
      if @params[:store]
        @context["stored_#{@params[:store]}".to_sym] = node
      end
      if Zena::Acts::Linkable::plural_method?(@method) || @params[:from]
        # plural
        # FIXME: could SQL injection be possible here ? (all params are passed to the 'find')
        erb_params = {}
        if order = @params[:order]
          if order == 'random'
            erb_params[:order] = 'RAND()'
          elsif order =~ /\A(\w+)( ASC| DESC|)\Z/
            erb_params[:order] = order
          else
            # ignore
          end
        end
        erb_params[:from] = @params[:from] if @params[:from]
        [:limit, :offset].each do |k|
          next unless @params[k]
          erb_params[k] = @params[k].to_i.to_s
        end
        conditions = []
        if value = @params[:author]
          if value == 'stored' && stored = @context[:stored_author]
            conditions << "user_id = '\#{#{stored}[:user_id]}'"
          elsif value == 'current'
            conditions << "user_id = '\#{#{node}[:user_id]}'"
          elsif value == 'visitor'
            conditions << "user_id = '\#{visitor[:id]}'"
          elsif value =~ /\A\d+\Z/
            conditions << "user_id = '#{value.to_i}'"
          elsif value =~ /\A[\w\/]+\Z/
            # path, not implemented yet
          end
        end
        
        if value = @params[:project]
          if value == 'stored' && stored = @context[:stored_project]
            conditions << "project_id = '\#{#{stored}[:project_id]}'"
          elsif value == 'current'
            conditions << "project_id = '\#{#{node}[:project_id]}'"
          elsif value =~ /\A\d+\Z/
            conditions << "project_id = '#{value.to_i}'"
          elsif value =~ /\A[\w\/]+\Z/
            # not implemented yet
          end
        end
        
        [:updated, :created, :event, :log].each do |k|
          if value = @params[k]
            # current, same are synonym for 'today'
            value = 'today' if ['current', 'same'].include?(value)
            conditions << Node.connection.date_condition(value,"#{k}_at",current_date)
          end
        end

        params = params_to_erb(erb_params)
        if conditions != []
          conditions = conditions.join(' AND ')
          if params != ''
            params << ", :conditions=>\"#{conditions}\""
          else
            params = ":conditions=>\"#{conditions}\""
          end
        end
        do_list("#{node}.relation(#{rel.inspect}#{params})")
      else
        # singular
        do_var("#{node}.relation(#{rel.inspect})")
      end
    end
    # <z:hot else='project'/>
    # <z:relation role='hot,project'> = get relation if empty get project
    # relation ? get ? role ? go ?
    
    # helpers
    # find the current node name in the context
    def node
      @context[:node] || '@node'
    end
    
    def current_date
      @context[:date] || '#{main_date.strftime("%Y-%m-%d")}'
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
    
    def node_kind_of?(klass)
      klass = Module::const_get(node_class)
      test_class = klass.kind_of?(Symbol) ? Module::const_get(klass) : klass
      klass.ancestors.include?(test_class)
    end
    
    def list
      @context[:list]
    end
    
    def helper
      @options[:helper]
    end
    
    def params_to_erb(params)
      res = ""
      params.each do |k,v|
        res << ", #{k.inspect}=>#{v.inspect}"
      end
      res
    end
    
    def do_var(var_finder=nil)
      expand_with(:preflight=>true)
      else_block = @pass[:else]
      out "<% if #{var} = #{var_finder} -%>" if var_finder
      res = expand_with(:node=>var)
      out render_html_tag(res)
      if else_block
        out "<% else -%>"
        out expand_block(else_block, :do=>true)
      end
      out "<% end -%>" if var_finder
    end
    
    def do_list(list_finder=nil)
      if list_finder
        out "<% if (#{list_var} = #{list_finder}) && #{list_var} != [] -%>"
      end
      
      @context.delete(:template_url) # should not propagate
      
      # preflight parse to see what we have
      expand_with(:preflight=>true)
      else_block = @pass[:else]
      if (form_block = @pass[:form]) && (each_block = @pass[:each]) && (@pass[:edit] || @pass[:add])
        # ajax
        template_url  = "#{@options[:current_folder]}/#{@context[:name] || "root"}_#{node_class}"
        
        # render without 'add' or 'form'
        res = expand_with(:list=>list_var, :no_add=>true, :no_form=>true, :template_url=>template_url)
        out render_html_tag(res)
        if list_finder
          out "<% else -%>" + expand_block(else_block, :do=>true) if else_block
          out "<% end -%>"
        end
        
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
        res = expand_with(:list=>list_var)
        out render_html_tag(res)
        if list_finder
          out "<% else -%>" + expand_block(else_block, :do=>true) if else_block
          out "<% end -%>"
        end
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
        "#{before}<#{tag}#{params_to_html(params)}>"
      end
    end
    
    # TODO: test
    def check_node_class(*list)
      list.include?(node_class)
    end
    
    # TODO: test
    def get_attribute(attribute)
      case attribute[0..1]
      when 'v_'
        ".version[#{attribute[2..-1].to_sym.inspect}]"
      when 'c_'
        ".version.content[#{attribute[2..-1].to_sym.inspect}]"
      else
        "[#{attribute.to_sym.inspect}]"
      end
    end
    
    
    def render_html_tag(text)
      return text if @html_tag_done
      if @html_tag
        res = "<#{@html_tag}#{params_to_html(@html_tag_params || {})}"
        if text != ''
          res << ">#{text}</#{@html_tag}>"
        else
          res << "/>"
        end
      else
        res = text
      end
      @html_tag_done = true
      (@options[:space_before] || '') + res + (@options[:space_after] || '')
    end
    
    def render_html_tag(text)
      return text if @html_tag_done
      set_params = {}
      @params.each do |k,v|
        next unless k.to_s =~ /^set_/
        set_params[k] = v
      end
      @html_tag = 'div' if !@html_tag && set_params != {}
      
      @html_tag_params ||= {}
      bak = @html_tag_params.dup
      res_params = {}
      set_params.merge(@html_tag_params).each do |k,v|
        if k.to_s =~ /^set_(.+)$/
          key = $1
          value = v.gsub(/\[([^\]]+)\]/) do
            "<%= #{node}#{get_attribute($1)} %>"
          end
          res_params[key.to_sym] = value
        else
          res_params[k] = v unless res_params[k]
        end
      end
      @html_tag_params = res_params
      res = super(text)
      @html_tag_params = bak
      res
    end
    
    def get_text_for_erb
      if @params[:attr]
        text = "#{node}#{get_attribute(@params[:attr])}"
      elsif @params[:tattr]
        text = "trans(#{node}#{get_attribute(@params[:tattr])})"
      elsif @params[:trans]
        text = helper.trans(@params[:trans]).inspect
      elsif @params[:text]
        text = @params[:text].inspect
      elsif @blocks != []
        res  = []
        text = ""
        static = true
        @blocks.each do |b|
          if b.kind_of?(String)
            res  << b.inspect
            text << b
          elsif ['show'].include?(b.method)
            res << expand_block(b, :trans=>true)
            static = false
          else
            # ignore
          end
        end
        if static
          text = text.inspect
        else
          text = res.join(' + ')
        end
      else
        text = nil
      end
      text
    end
  end
end

module ActiveRecord
  module ConnectionAdapters
    class MysqlAdapter
      def date_condition(date_cond, field, ref_date='today')
        if ref_date == 'today'
          ref_date = 'now()'
        else
          ref_date = "'#{ref_date.gsub("'",'')}'"
        end
        case date_cond
        when 'today'
          "DATE(#{field}) = DATE(#{ref_date})"
        when 'week'
          "date_format(#{ref_date},'%Y-%v') = date_format(#{field}, '%Y-%v')"
        when 'month'
          "date_format(#{ref_date},'%Y-%m') = date_format(#{field}, '%Y-%m')"
        when 'year'
          "date_format(#{ref_date},'%Y') = date_format(#{field}, '%Y')"
        when 'upcoming'
          "DATEDIFF(#{field},#{ref_date}) > 0"
        else
          if date_cond =~ /^(\+|-|)(\d+)day/
            count = $2.to_i
            if $1 == ''
              # +/- x days
              "ABS(DATEDIFF(#{field},#{ref_date})) <= #{count}"
            elsif $1 == '+'
              # x upcoming days
              "DATEDIFF(#{field},#{ref_date}) > 0 AND DATEDIFF(#{field},#{ref_date}) <= #{count}"
            else
              # x days in the past
              "DATEDIFF(#{field},#{ref_date}) < 0 AND DATEDIFF(#{field},#{ref_date}) >= -#{count}"
            end
          end
        end
      end
    end
  end
end