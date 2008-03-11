begin
  # FIXME: zafu_readable should belong to core_ext.
  class ActiveRecord::Base
    @@_zafu_readable ||= {} # defined for each class
    @@_zafu_context  ||= {} # defined for each class (list of methods to change contexts)
    @@_zafu_readable_attributes ||= {} # full list with inherited attributes
    @@_zafu_known_contexts      ||= {} # full list with inherited attributes
  
    def self.zafu_readable(*list)
      @@_zafu_readable[self] ||= []
      @@_zafu_readable[self] = (@@_zafu_readable[self] + list.map{|l| l.to_s}).uniq
    end
    
    def self.zafu_context(hash)
      @@_zafu_context[self] ||= {}
      @@_zafu_context[self].merge!(hash.stringify_keys)
    end
  
    def self.zafu_readable_attributes
      @@_zafu_readable_attributes[self] ||= if superclass == ActiveRecord::Base
        @@_zafu_readable[self] || []
      else
        (superclass.zafu_readable_attributes + (@@_zafu_readable[self] || [])).uniq.sort
      end
    end
    
    def self.zafu_known_contexts
      @@_zafu_known_contexts[self] ||= begin
        res = {}
        if superclass == ActiveRecord::Base
          @@_zafu_context[self] || {}
        else
          superclass.zafu_known_contexts.merge(@@_zafu_context[self] || {})
        end.each do |k,v|
          if v.kind_of?(Array)
            if v[0].kind_of?(String)
              res[k] = [Module::const_get(v[0])]
            else
              res[k] = v
            end
          else
            if v.kind_of?(String)
              res[k] = Module::const_get(v)
            else
              res[k] = v
            end
          end
        end
        res
      end
    end
  
    def self.zafu_readable?(sym)
      if sym.to_s =~ /(.*)_zips?$/
        return true if self.ancestors.include?(Node) && Relation.find_by_role($1.singularize)
      end
      self.zafu_readable_attributes.include?(sym.to_s)
    end
  
    def zafu_read(sym)
      return "'#{sym}' not readable" unless self.class.zafu_readable?(sym)
      self.send(sym)
    end
  end
rescue NameError
  puts "Testing out of Rails, ActiveRecord uninitialized."
end

module Zena
  module Rules
  end
  
  # Zafu tags used to display / edit nodes and versions
  module Tags
    class << self
      def inline_methods(*args)
        args.each do |name|
          class_eval <<-END
            def r_#{name}
              "<%= #{name}(:node=>\#{node}\#{params_to_erb(@params)}) %>"
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
      return unless super
      
      @var = nil # reset var counter
      
      # some 'html_tag' information can be set during rendering and should merge into tag_params
      @html_tag_params_bak = @html_tag_params
      @html_tag_params     = @html_tag_params.merge(@context.delete(:html_tag_params) || {})
      if key = @params.delete(:store)
        set_stored(Node, key, node)
      end
      
      if key = @params.delete(:store_date)
        set_stored(Date, key, current_date)
      end
      @anchor_param = @params.delete(:anchor)

      true
    end
    
    def do_method(sym)
      method = sym
      if method == :r_unknown
        if @method =~ /^\[(.*)\]$/
          @params[:attr] = $1
          method = :r_show
        elsif @method =~ /^\{(.*)\}$/
          @params[:attr] = $1
          method = :r_zazen
        end
      end
      
      if @context[:make_form]
        res = case method
        when :r_title
          make_input(:name => 'v_title')
        when :r_link
          make_input(:name => (@params[:attr] || 'v_title'))
        when :r_show
          make_input(:name => (@params[:attr] || @params[:tattr]), :date => @params[:date])
        when :r_text
          make_textarea(:name => 'v_text')
        when :r_summary
          make_textarea(:name => 'v_summary')
        when :r_zazen
          make_textarea(:name => @params[:attr])
        else
          if node_kind_of?(DataEntry) && @method.to_s =~ /node_/
            # select node_id
            "<%= select_id('#{base_class.to_s.underscore}', '#{@method}_id') %>"
          else
            return super(method) # use normal rendering
          end
        end
        res =  "<#{@html_tag || 'div'} class='zazen'>#{res}</#{@html_tag || 'div'}>" if [:r_summary, :r_text].include?(sym)
          
        return res if res
      end
      
      
      super(method)
    end
    
    
    def after_render(text)
      if @anchor_param
        @params[:anchor] = @anchor_param # set back in case of double rendering so it is computed again
        res = render_html_tag(r_anchor + super)
      else
        res = render_html_tag(super)
      end
      @html_tag_params = @html_tag_params_bak # ???
      res
    end

    def r_show
      attribute = @params[:attr] || @params[:tattr]
      if @params[:tattr]
        attribute_method = "_(#{node_attribute(attribute, :else=>@params[:else])})"
      elsif @params[:attr]
        if @params[:format]
          attribute_method = "sprintf(#{@params[:format].inspect}, #{node_attribute(attribute, :else=>@params[:else])})"
        else
          attribute_method = "#{node_attribute(attribute, :else=>@params[:else])}"
        end
      elsif @params[:date]
        # date can be any attribute v_created_at or updated_at etc.
        # TODO format with @params[:format] and @params[:tformat] << translated format
        # TODO: test
        if @params[:tformat]
          format = _(@params[:tformat])
        elsif @params[:format]
          format = @params[:format]
        else
          format = "%Y-%m-%d"
        end
        attribute_method = "format_date(#{node_attribute(@params[:date])}, #{format.inspect})"
      elsif @context[:trans]
        # error
        return "no attribute for 'show'".inspect
      else  
        return "<span class='parser_error'>[show] missing attribute</span>"
      end
      
      if @context[:trans]
        # TODO: what do we do here with gsubs, url ?
        return attribute_method
      end
      
      if gsub = @params[:gsub]
        if gsub =~ /\A\/(.+)\/(.+)\/\Z/
          value = $2
          key   = $1.gsub(/\#([\{\$\@])/,'# \1') # FIXME: SECURITY.
                                                 # Please note that .gsub(/#([\{\$\@])/,'\#\1') won't work, since '\#{blah}' will become '\\#{blah}' and 'blah' will be evaluated.
          begin
            re = /#{key}/
          rescue => err
            # invalid regexp
            return "<span class='parser_error'>[show] invalid gsub #{gsub.inspect}</span>"
          end
          attribute_method = "#{attribute_method}.to_s.gsub(/#{key}/,#{value.inspect})"
        else
          # error
          return "<span class='parser_error'>[show] invalid gsub #{gsub.inspect}</span>"
        end
      end
      
      if @params[:actions]
        actions = "<%= node_actions(:node=>#{node}#{params_to_erb(:actions=>@params[:actions], :publish_after_save=>(@params[:publish] == 'true'))}) %>"
      else
        actions = ''
      end
      
      if @params[:edit] == 'true' && !['url','path'].include?(attribute)
        name = unique_name + '_' + attribute
        # TODO: add can_drive? or can_write? clauses.
        "<span id='#{name}.<%= #{node}.zip %>'>#{actions}<%= link_to_remote(#{attribute_method}, :url => edit_node_path(#{node}.zip) + \"?attribute=#{attribute}&identifier=#{CGI.escape(name)}.\#{#{node}.zip}\", :method => :get) %></span>"
      else
        "#{actions}<%= #{attribute_method} %>"
      end
    end
    
    def r_zazen
      attribute = @params[:attr] || @params[:tattr]
      limit  = @params[:limit] ? ", :limit=>#{@params[:limit].to_i}" : ""
      if @context[:trans]
        # TODO: what do we do here with dates ?
        "#{node_attribute(attribute)}"
      elsif @params[:tattr]
        "<%= zazen(_(#{node_attribute(attribute)})#{limit}, :node=>#{node}) %>"
      elsif @params[:attr]
        if output_format == 'html'
          "<%= zazen(#{node_attribute(attribute)}#{limit}, :node=>#{node}) %>"
        else
          "<%= zazen(#{node_attribute(attribute)}#{limit}, :node=>#{node}, :output=>#{output_format.inspect}) %>"
        end
      elsif @params[:date]
        # date can be any attribute v_created_at or updated_at etc.
        # TODO format with @params[:format] and @params[:tformat] << translated format
      else
        # error
      end
    end
    
    # TODO: test, rename ?
    def r_search_results
      do_list("@nodes")
    end
    
    # TODO: write a test (please)
    # FIXME: we should use a single way to change a whole context into a template (applies to 'each', 'form', 'group'). Then 'swap' could use the 'each' block.
    # Define a group of elements to be used by ajax calls (edit/filter)
    def r_group
      if @context[:group] == self
        # called from self (storing template)
        @html_tag_done = false
        @html_tag_params.merge!(:id=>"#{dom_id_from_template_url(@context[:template_url])}.<%= #{node}.zip %>")
        out expand_with
      else
        template_url = get_template_url
        form_url     = template_url + '_form'
      
        @html_tag ||= 'div'
      
        unless @context[:make_form]
          # STORE TEMPLATE ========
          template_node = "@#{base_class.to_s.underscore}"
          context_bak = @context.dup # avoid side effects when rendering the same block
            template      = expand_block(self, :group=>self, :list=>false, :node=>template_node, :template_url=>template_url, :form=>false, :no_form => true)
          @context = context_bak
          @result  = ''
          out helper.save_erb_to_url(template, template_url)
      
          if descendant('edit')
            if form = descendant('form')
              # USE GROUP FORM ========
              form_text = form.render
            else
              # MAKE A FORM FROM GROUP ========
              form = self.dup
              form.method = 'form'
              form_text = expand_block(form, @context.merge(:make_form => true, :list => false, :node => template_node, :template_url=>template_url))
            end
            out helper.save_erb_to_url(form_text, form_url)
          end
        end
        
        @html_tag_done = false
        @html_tag_params.merge!(:id=>"#{dom_id_from_template_url(template_url)}.<%= #{node}.zip %>")
        out expand_with(:template_url => template_url)
      end
    end
    
    # TODO: test
    def r_filter
      return "span class='parser_error'>[filter] missing 'group' in same parent</span>" unless parent && group = parent.descendant('group')
      dom_id       = group.dom_id(@context)
      template_url = group.get_template_url(@context)
      out "<%= form_remote_tag(:url => zafu_node_path(#{node}.zip), :method => :get, :html => {:id => \"#{dom_id}_q\"}) %><div class='hidden'><input type='hidden' name='template_url' value='#{template_url}'/></div><div class='wrapper'><input type='text' name='#{@params[:key] || 'f'}' value='<%= params[#{(@params[:key] || 'f').to_sym.inspect}] %>'/></div></form>"
      if @params[:live]
        out "<%= observe_form( \"#{dom_id}_q\" , :method => :get, :frequency  =>  1, :submit =>\"#{dom_id}_q\", :url => zafu_node_path(#{node}.zip)) %>"
      end
    end
    
    # swap an attribute
    # TODO: test
    def r_swap
      if group = ancestor('group') || ancestor('each')
        # ancestor: ok
      elsif parent && group = parent.descendant('group')
        # sibling: ok
      else
        return "span class='parser_error'>[swap] missing 'group' in same parent</span>"
      end
      template_url = group.get_template_url(@context)
      states = (@params[:states] || 'todo, done').split(',').map{|e| e.strip}
      if states.include?("")
        text = get_text_for_erb(@params.merge(:attr=>nil))
      else
        text = get_text_for_erb
      end
      
      auto_publish = @params[:publish] ? "&node[v_status]=#{Zena::Status[:pub]}" : ''
            
      out "<%= #{node}.can_write? ? link_to_remote(#{text}, {:url => node_path(#{node}.zip) + \"?template_url=#{CGI.escape(template_url)}#{auto_publish}&node[#{@params[:attr]}]=\#{#{states.inspect}[ ((#{states.inspect}.index(#{node_attribute(@params[:attr])}) || 0)+1) % #{states.size}]}\", :method => :put}) : '' %>"
    end
    
    
    def r_trans
      static = true
      if @params[:text]
        text = @params[:text]
      elsif @params[:attr]
        text = "#{node_attribute(@params[:attr])}"
        static = false
      else
        res  = []
        text = ""
        @blocks.each do |b|
          if b.kind_of?(String)
            res  << b.inspect
            text << b
          elsif ['show', 'current_date'].include?(b.method)
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
        helper.send(:_,text)
      else
        "<%= _(#{text}) %>"
      end
    end
        
    def r_anchor(obj=node)
      if @anchor_param =~ /\[(.+)\]/
        anchor_value = "<%= #{node_attribute($1)} %>"
      elsif node_kind_of?(Version)
        anchor_value = "#{base_class.to_s.underscore}<%= #{obj}.node.zip %>.<%= #{obj}.number %>"
      else
        anchor_value = "#{base_class.to_s.underscore}<%= #{obj}.zip %>"
      end
      "<a name='#{anchor_value}'></a>"
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
    
    def r_check_lang
      text = @params[:text]   || expand_with
      klass = @params[:class] || @html_tag_params[:class]
      text = nil if text.blank?
      klas = nil if klass.blank?
      @html_tag_done = true
      "#{@space_before}<%= check_lang(#{node},:text=>#{text.inspect},:class=>#{klass.inspect},:wrap=>#{@html_tag.inspect}) %>"
    end
    
    def r_title
      if node_kind_of?(Version)
        node = "#{self.node}.node"
      else
        node = self.node
      end
      title_params = {}
      [:link, :check_lang].each do |sym|
        title_params[sym] = @params[sym] if @params.include?(sym)
      end
      res = "<%= show_title(:node=>#{node}#{params_to_erb(title_params)}"
      if @params.include?(:attr)
        res << ", :text=>#{node_attribute(@params[:attr])}"
      elsif (text = expand_with(:only => [:string])) != ''
        res << ", :text=>#{text.inspect}"
      end
      
      if @params.include?(:project)
        res << ", :project=>#{@params[:project] == 'true'}"
      end
      res << ")"
      if @params[:actions]
        res << " + node_actions(:node=>#{node}#{params_to_erb(:actions=>@params[:actions], :publish_after_save=>(@params[:publish] == 'true'))})"
      end
      res << "%>"
      if @params[:status] == 'true' || (@params[:status].nil? && @params[:actions])
        if @html_tag_params[:class]
         "<div class='s<%= #{node}.version.status %>'>#{res}</div>"
        else
          @html_tag_params[:class] = ["'s<%= #{node}.version.status %>'"]
          res
        end
      else
        res
      end
    end
    
    # TODO: test
    def r_actions
      out expand_with
      out "<%= node_actions(:node=>#{node}#{params_to_erb(:actions=>@params[:select], :publish_after_save=>(@params[:publish] == 'true'))}) %>"
    end
    
    # TODO: test
    def r_admin_links
      "<%= show_link(:admin_links).join('</#{@html_tag}><#{@html_tag}>') %>"
    end
    
    def r_text
      text = @params[:text] ? @params[:text].inspect : "#{node_attribute('v_text')}"
      limit  = @params[:limit] ? ", :limit=>#{@params[:limit].to_i}" : ""
      out "<div id='v_text<%= #{node}.zip %>' class='zazen'>"
      unless @params[:empty] == 'true'
        out "<% if #{node}.kind_of?(TextDocument); l = #{node}.content_lang -%>"
        out "<%= zazen(\"<code\#{l ? \" lang='\#{l}'\" : ''} class=\\'full\\'>\#{#{text}}</code>\") %></div>"
        out "<% else -%>"
        out "<%= zazen(#{text}#{limit}, :node=>#{node}) %>"
        out "<% end -%>"
      end
      out "</div>"
    end
    
    def r_inspect
      out ["params: #{@params.inspect}", 
      "name:   #{@context[:name]}",
      "node:   #{node}",
      "list:   #{list}"].join("<br/>")
    end
    
    # TODO: replace with a more general 'zazen' or 'show' with id ?
    def r_summary
      limit  = @params[:limit] ? ", :limit=>#{@params[:limit].to_i}" : ""
      unless @params[:or]
        text = @params[:text] ? @params[:text].inspect : node_attribute('v_summary')
        "<div id='v_summary<%= #{node}.zip %>' class='zazen'><%= zazen(#{text}#{limit}, :node=>#{node}) %></div>"
      else
        limit ||= ', :limit => 2'
        first_name = 'v_summary'
        first  = node_attribute(first_name)
        
        second_name = @params[:or].gsub(/[^a-z_]/,'') # FIXME: ist this still needed ? (ERB injection)
        second = node_attribute(second_name)
        "<div id='#{first_name}<%= #{node}.zip %>' class='zazen'><% if #{first} != '' %>" +
        "<%= zazen(#{first}, :node=>#{node}) %>" +
        "<% else %>" +
        "<%= zazen(#{second}#{limit}, :node=>#{node}) %>" +
        "<% end %></div>"
      end
    end
    
    def r_show_author
      if @params[:size] == 'large'
        out "#{_("posted by")} <b><%= #{node}.author.fullname %></b>"
        out "<% if #{node}[:user_id] != #{node}.version[:user_id] -%>"
        out "<% if #{node}[:ref_lang] != #{node}.version[:lang] -%>"
        out "#{_("traduction by")} <b><%= #{node}.version.author.fullname %></b>"
        out "<% else -%>"
        out "#{_("modified by")} <b><%= #{node}.version.author.fullname %></b>"
        out "<% end"
        out "   end -%>"
        out " #{_("on")} <%= format_date(#{node}.version.updated_at, #{_('short_date').inspect}) %>."
        if @params[:traductions] == 'true'
          out " #{_("Traductions")} : <span class='traductions'><%= helper.traductions(:node=>#{node}).join(', ') %></span>"
        end
      else
        out "<b><%= #{node}.version.author.initials %></b> - <%= format_date(#{node}.version.updated_at, #{_('short_date').inspect}) %>"
        if @params[:traductions] == 'true'
          out " <span class='traductions'>(<%= helper.traductions(:node=>#{node}).join(', ') %>)</span>"
        end
      end
    end
    
    # FIXME: replace by zafu_known_contexts, each, etc
    def r_comments
      "<%= render :partial=>'comments/list', :locals=>{:node=>#{node}} %>"
    end
    
    def r_edit
      text = get_text_for_erb
      if template_url = @context[:template_url]
        # ajax
        if @context[:in_form]
          # cancel button
          @context[:form_cancel] || ''
          # "<%= link_to_remote(#{_('cancel').inspect}, {:url => node_path(#{node}.zip) + '/zafu?template_url=#{CGI.escape(template_url)}', :method => :get}#{params_to_erb(@params)}) %>"
        else
          # edit button
          "<%= #{node}.can_write? ? link_to_remote(#{text || _('edit').inspect}, {:url => edit_#{base_class.to_s.underscore}_path(#{node}.zip) + '?template_url=#{CGI.escape(template_url)}', :method => :get}#{params_to_erb(@params)}) : '' %>"
        end
      else
        # FIXME: we could link to some html page to edit the item.
        ""
      end
    end
    
    alias r_cancel r_edit
    
    def r_textarea
      out make_textarea(@html_tag_params.merge(@params))
      @html_tag_done = true
    end
    
    def r_input
      input, attribute = get_input_params()
      
      case @params[:type]
      when 'select' # FIXME: why is this only for classes ?
        return "<span class='parser_error'>[input] select without name</span>" unless attribute
        if klass = @params[:root_class]
          select_opts = {}
          class_opts = {}
          select_opts[:selected] = @params[:selected] if @params[:selected]
          class_opts[:without]  = @params[:without]  if @params[:without]
          # do not use 'selected' if the node is not new
          "<% if #{node}.new_record? -%><%= select('#{base_class.to_s.underscore}', #{attribute.inspect}, Node.classes_for_form(:class => #{klass.inspect}#{params_to_erb(class_opts)})#{params_to_erb(select_opts)}) %><% else -%><%= select('#{base_class.to_s.underscore}', #{attribute.inspect}, Node.classes_for_form(:class => #{klass.inspect}#{params_to_erb(class_opts)})) %><% end -%>"
        else
          klasses = @params[:options] || "Page,Note"
          "<%= select('#{base_class.to_s.underscore}', #{attribute.inspect}, #{klasses.split(',').map(&:strip).inspect}) %>"
        end
      when 'date_box', 'date'
        return "<span class='parser_error'>[input] date_box without name</span>" unless attribute
        input_id = @context[:template_url] ? ", :id=>#{(dom_id_from_template_url + '_' + attribute.to_s).inspect} + #{node}.zip.to_s" : ''
        "<%= date_box '#{base_class.to_s.underscore}', #{attribute.inspect}, :size=>15#{@context[:in_add] ? ", :value=>''" : ''}#{input_id} %>"
      when 'id'
        return "<span class='parser_error'>[input] select id without name</span>" unless attribute
        name = "#{attribute}_id" unless attribute[-3..-1] == '_id'
        input_id = params[:input_id] ? ", :input_id => #{(dom_id_from_template_url + '_' + attribute.to_s).inspect}" : ''
        "<%= select_id('#{base_class.to_s.underscore}', #{attribute.inspect}#{input_id}) %>"
        
      when 'submit'
        @html_tag = 'input'
        @html_tag_params[:type] = @params[:type]
        @html_tag_params[:text] = @params[:text]
        @html_tag_params.merge!(input)
        render_html_tag(nil)
      else
        # 'text', 'hidden', ...
        @html_tag = 'input'
        @html_tag_params[:type] = @params[:type] || 'text'
        @html_tag_params.merge!(input)
        render_html_tag(nil)
      end
    end
    
    def r_form_tag
      # replace <form> with constructed form
      "#{@context[:form_tag]}#{expand_with(:form_tag => nil)}</form>"
    end
    
    # TODO: add parent_id into the form !
    # TODO: add <div style="margin:0;padding:0"><input name="_method" type="hidden" value="put" /></div> if method == put
    # FIXME: use <r:form href='self'> or <r:form action='...'>
    def r_form
      if template_url = @context[:template_url]
        # ajax
        
        if @context[:in_add]
          # inline form used to create new elements: set values to '' and 'parent_id' from context
          @html_tag_params.merge!(:id=>"#{dom_id_from_template_url}_form", :style=>"display:none;")
          cancel =  "<p class='btn_x'><a href='#' onclick='[\"#{dom_id_from_template_url}_add\", \"#{dom_id_from_template_url}_form\"].each(Element.toggle);return false;'>#{_('btn_x')}</a></p>\n"
          form  =  "<%= form_remote_tag(:url => #{base_class.to_s.underscore.pluralize}_path) %>\n"
        else
          # saved form used to edit/create: set values and 'parent_id' from @node
          @html_tag_params.merge!(:id=>"#{dom_id_from_template_url}<%= #{node}.new_record? ? '_form' : \".\#{#{node}.zip}\" %>") unless @method == 'group' # called from r_group
          # new_record? = edit/create failed, rendering form with errors
          # else        = edit
          # FIXME: remove '/zafu?' when nodes_controller's method 'zafu' is no longer needed.
          cancel = <<-END_TXT
<% if #{node}.new_record? -%>
  <p class='btn_x'><a href='#' onclick='[\"#{dom_id_from_template_url}_add\", \"#{dom_id_from_template_url}_form\"].each(Element.toggle);return false;'>#{_('btn_x')}</a></p>
<% else -%>
  <p class='btn_x'><%= link_to_remote(#{_('btn_x').inspect}, :url => #{base_class.to_s.underscore}_path(#{node}.zip) + '/zafu?template_url=#{CGI.escape(template_url)}', :method => :get) %></a></p>
<% end -%>
END_TXT
          form =<<-END_TXT
<% if #{node}.new_record? -%>
<%= form_remote_tag(:url => #{base_class.to_s.underscore.pluralize}_path) %>
<% else -%>
<%= form_remote_tag(:url => #{base_class.to_s.underscore}_path(#{node}.zip), :method => :put) %>
<% end -%>
END_TXT
        end
        
        form << "<div class='hidden'>"
        form << "<input type='hidden' name='template_url' value='#{template_url}'/>\n"
        form << "<input type='hidden' name='node[v_status]' value='#{Zena::Status[:pub]}'/>\n" if @context[:publish_after_save] || (@params[:publish] == 'true')
        
        if node_kind_of?(Node)
          form << "<input type='hidden' name='node[parent_id]' value='<%= #{@context[:in_add] ? "#{@context[:parent_node]}.zip" : "#{node}.parent_zip"} %>'/>\n"
          
          if (@params[:klass] || @context[:in_add] || @context[:klass])
            klass_set = false
            (descendants['input'] || []).each do |tag|
              if tag.params[:name] == 'klass'
                klass_set = true
                break
              end
            end
            form << "<input type='hidden' name='node[klass]' value='#{@params[:klass] || @context[:klass] || 'Page'}'/>\n" unless klass_set
          end
        end
        
        if add_block = @context[:add]
          params = add_block.params
          [:after, :before, :top, :bottom].each do |sym|
            if params[sym]
              form << "<input type='hidden' name='position' value='#{sym}'/>\n"
              if params[sym] == 'self'
                if sym == :before
                  form << "<input type='hidden' name='reference' value='#{dom_id_from_template_url}_add'/>\n"
                else
                  form << "<input type='hidden' name='reference' value='#{dom_id_from_template_url}_form'/>\n"
                end
              else  
                form << "<input type='hidden' name='reference' value='#{params[sym]}'/>\n"
              end
              break
            end
          end
          if params[:done] == 'focus'
            form << "<input type='hidden' name='done' value=\"$('#{dom_id_from_template_url}_#{add_block.params[:focus] || 'v_title'}').focus();\"/>\n"
          elsif params[:done]
            form << "<input type='hidden' name='done' value=#{params[:done].inspect}/>\n"
          end
        end
        
        form << "</div>"
        form << "<%= error_messages_for(#{node}) %>"
      else
        # no ajax
        # FIXME
        cancel = "" # link to normal node ?
        form = "<form method='post' action='/nodes/<%= #{node}.zip %>'><div style='margin:0;padding:0'><input name='_method' type='hidden' value='put' /></div>"
      end
      
      unless descendant('cancel') || descendant('edit') || descendant('form_tag')
        # add a descendant before blocks.
        blocks_bak = @blocks.dup # I do not understand why we need 'dup' (but we sure do...)
        form_cancel = make(:void, :method=>'void', :text=>cancel)
        @blocks = [form_cancel] + blocks_bak
      else
        blocks_bak = @blocks
      end
      
      if descendant('form_tag') && !(descendant('cancel') || descendant('edit'))
        form = cancel + form
        cancel = ''
      end
      
      if descendant('form_tag')
        res = expand_with(:form_tag => form, :in_form => true, :form_cancel => cancel)
      else
        #res = "&lt;form&gt; missing"
        res = form + expand_with(:in_form => true, :form_cancel => cancel) + '</form>'
      end
      @blocks = blocks_bak
      out render_html_tag(res)
    end
    
    # <r:checkbox role='collaborator_for' values='projects' from='site'/>"
    # TODO: implement menu 'select' in the same spirit
    def r_checkbox
      return "<span class='parser_error'>[checkbox] missing 'values'</span>" unless values = @params[:values]
      return "<span class='parser_error'>[checkbox] missing 'role'</span>"   unless   role = (@params[:role] || @params[:name])
      meth = role.singularize
      attribute = @params[:attr] || 'name'
      if values =~ /^\d+\s*($|,)/
        # ids
        # TODO generate the full query instead of using secure.
        values = values.split(',').map{|v| v.to_i}
        list_finder = "(secure(Node) { Node.find(:all, :conditions => 'zip IN (#{values.join(',')})') })"
      else
        # relation
        list_finder = build_finder_for(:all, values)
      end
      out "<% if (#{list_var} = #{list_finder}) && (#{list_var}_relation = #{node}.relation_proxy(:role=>#{role.inspect}, :ignore_source=>true)) -%>"
      out "<% if #{list_var}_relation.unique? -%>"
    
      out "<% #{list_var}_id = #{list_var}_relation.other_id -%>"
      out "<div class='input_radio'><% #{list_var}.each do |#{var}| -%>"
      out "<span><input type='radio' name='node[#{meth}_id]' value='<%= #{var}.zip %>'<%= #{list_var}_id == #{var}[:id] ? \" checked='checked'\" : '' %>/> <%= #{node_attribute(attribute, :node=>var)} %></span> "
      out "<% end -%></div>"
      out "<input type='radio' name='node[#{meth}_id]' value=''/> #{_('none')}"

      out "<% else -%>"

      out "<% #{list_var}_ids = #{list_var}_relation.other_ids -%>"
      out "<div class='input_checkbox'><% #{list_var}.each do |#{var}| -%>"
      out "<span><input type='checkbox' name='node[#{meth}_ids][]' value='<%= #{var}.zip %>'<%= #{list_var}_ids.include?(#{var}[:id]) ? \" checked='checked'\" : '' %>/> <%= #{node_attribute(attribute, :node=>var)} %></span> "
      out "<% end -%></div>"
      out "<input type='hidden' name='node[#{meth}_ids]' value=''/>"

      out "<% end -%><% end -%>"
    end
    
    alias r_radio r_checkbox
    
    # TODO: test
    def r_add
      return "<span class='parser_error'>[add] should not be called from within 'each'</span>" if parent.method == 'each'
      return '' if @context[:make_form]
      out "<% if #{node}.can_write? -%>"
      unless descendant('add_btn')
        # add a descendant between self and blocks.
        blocks = @blocks.dup
        @blocks = []
        add_btn = make(:void, :method=>'add_btn', :params=>@params.dup, :text=>'')
        add_btn.blocks = blocks
        remove_instance_variable(:@descendants)
      end
      
      if @context[:form] && @context[:template_url]
        # ajax add
        prefix  = dom_id_from_template_url
        @html_tag_params.merge!(:id => "#{prefix}_add")
        @html_tag_params[:class] ||= 'btn_add'
        focus = "$(\"#{prefix}_#{@params[:focus] || 'v_title'}\").focus();"
        
        out render_html_tag("#{expand_with(:onclick=>"[\"#{prefix}_add\", \"#{prefix}_form\"].each(Element.toggle);#{focus}return false;")}")
        
        if node_kind_of?(Node)
          # FIXME: BUG if we set <r:form klass='Post'/> the user cannot select class with menu...
          klass = @context[:klass] || 'Node'
          # FIXME: inspect '@context[:form]' to see if it contains v_klass ?
          out "<% if #{var}_new = secure(Node) { Node.new_from_class(#{klass.inspect}) } -%>"
        else
          out "<% if #{var}_new = #{node_class}.new -%>"
        end
        if @context[:form].method == 'form'
          out expand_block(@context[:form], :in_add => true, :no_form => false, :add=>self, :node => "#{var}_new", :parent_node => node, :klass => klass, :publish_after_save => (@params[:publish] == 'true'))
        else
          # build form from 'each'
          out expand_block(@context[:form], :in_add => true, :no_form => false, :no_edit => true, :add=>self, :make_form => true, :node => "#{var}_new", :parent_node => node, :klass => klass, :publish_after_save => (@params[:publish] == 'true'))
        end
        out "<% end -%>"
      else
        # no ajax
        @html_tag_params[:class] ||= 'btn_add' if @html_tag
        out render_html_tag(expand_with)
      end
      out "<% end -%>"
      @html_tag_done = true
    end
    
    def r_add_btn
      if @params[:text]
        text = @params[:text]
        text = "<div>#{text}</div>" unless @html_tag
      elsif @params[:trans]
        text = _(@params[:trans])
        text = "<div>#{text}</div>" unless @html_tag
      elsif @blocks != []
        text = expand_with
      else
        text = _("btn_add")
      end
      
      out "<a href='#' onclick='#{@context[:onclick]}'>#{text}</a>"
    end
    
    # Show html to add open a popup window to add a document.
    # TODO: inline ajax for upload ?
    def r_add_document
      return "<span class='parser_error'>[add_document] only works with nodes (not with #{node_class})</span>" unless node_kind_of?(Node)
      "<% if #{node}.can_write? -%><a href='/documents/new?parent_id=<%= #{node}.zip %>' onclick='uploader=window.open(\"/documents/new?parent_id=<%= #{node}.zip %>\", \"upload\", \"width=400,height=300\");return false;'>#{_('btn_add_doc')}</a><% end -%>"
    end
    
    #if RAILS_ENV == 'test'
    #  def r_test
    #    inspect
    #  end
    #end
    def r_drop
      if action = @params[:set] || @params[:add]
        action = "set=#{CGI.escape(action)}"
      else
        return "<span class='parser_error'>[drop] missing 'set' or 'add'</span>"
      end
      
      @html_tag ||= 'div'
      template_url = get_template_url
      @html_tag_params ||= {}
      @html_tag_params[:id] = @html_tag_params[:id] ? CGI.escape(@html_tag_params[:id]) : template_url
      @html_tag_params[:class] ||= 'drop'
      
      action << "&template_url=#{CGI.escape(template_url)}"
      action << "&dom_id=#{@html_tag_params[:id]}"
      out render_html_tag(expand_with)
      # out "<%= drop_receiving_element('#{@html_tag_params[:id]}', :url => drop_node_path(#{node}.zip) + #{action.inspect}, :method => :put, :revert=>true) %>"
      # BUG WITH &amp. USING RAW JS BELOW. 
      out "<script type='text/javascript'>
      //<![CDATA[
      Droppables.add('#{@html_tag_params[:id]}', {onDrop:function(element){new Ajax.Request('/nodes/<%= #{node}.zip %>/drop?#{action}', {asynchronous:true, evalScripts:true, method:'put', parameters:'drop=' + encodeURIComponent(element.id)})}})
      //]]>
      </script>"
      
      # TEMPLATE ========
      template_node = "@#{base_class.to_s.underscore}"
      template      = expand_with(:node=>template_node, :template_url=>template_url)
      out helper.save_erb_to_url(template, template_url)
    end
    
    def r_draggable
      @html_tag ||= 'div'
      @html_tag_params ||= {}
      dom_id = unique_name
      @html_tag_params[:id] = "#{dom_id}.<%= #{node}.zip %>"
      case @params[:revert]
      when 'move'
        revert_effect = 'Element.move'
      when 'remove'
        revert_effect = 'Element.remove'
      else
        revert_effect = 'Element.move'
      end
      out expand_with
      out "</div>"
      out "<script type='text/javascript'>
      //<![CDATA[
      Zena.draggable('#{@html_tag_params[:id]}',true,true,#{revert_effect})
      //]]>
      </script>"
    end
 
    def r_unlink
      text = expand_with
      if text.blank?
        text = _('btn_tiny_del')
      end
      dom_id = "#{CGI.escape(@context[:dom_id])}.\#{#{node}.zip}"
      # amp bug, we have to build the path ourselves.
      out "<% if #{node}[:link_id] -%><%= link_to_remote(#{text.inspect}, {:url => \"/nodes/\#{#{node}[:zip]}/remove_link?link_id=\#{#{node}[:link_id]}&remove=#{dom_id}\", :method => :put}, :class=>#{(@params[:class] || 'unlink').inspect}) %><% end -%>"
    end
    

    def r_each
      if @context[:make_form]
        # use the elements inside 'each' loop to produce the edit form
        r_form
      elsif @context[:list]
        # normal rendering: inserted into the layout
        if @params[:draggable] == 'true'
          out "<% #{var}_dom_ids = [] -%>"
        end
        
        if join = @params[:join]
          join = join.gsub(/&lt;([^%])/, '<\1').gsub(/([^%])&gt;/, '\1>')
          out "<% #{list}.each_index do |#{var}_index| -%>"
          out "<%= #{var}=#{list}[#{var}_index]; #{var}_index > 0 ? #{join.inspect} : '' %>"
        else
          out "<% #{list}.each do |#{var}| -%>"
        end
        
        #dom_id = @context[:template_url] || self.dom_id()
        
        if @params[:draggable] == 'true'
          out "<% #{var}_dom_ids << \"#{dom_id}.\#{#{var}.zip}\" -%>"
        end
        
        out r_anchor(var) if @anchor_param # insert anchor inside the each loop
        @params[:anchor] = @anchor_param   # set back in case we double render
        @anchor_param = nil
        
        if @context[:template_url] || @params[:draggable] == 'true' || descendant('unlink')
          # ajax, set id
          id_hash = {:id=>"#{dom_id}.<%= #{var}.zip %>"}
          if @html_tag
            @html_tag_params.merge!(id_hash)
            res = expand_with(:node=>var, :dom_id=>dom_id) # dom_id is needed by 'unlink'
          else
            res = add_params(expand_with(:node=>var, :dom_id=>dom_id), id_hash)
          end
        else
          res = expand_with(:node=>var)
        end
        out render_html_tag(res)
        out "<% end -%>"
        
        if @params[:draggable] == 'true'
          out "<script type='text/javascript'>\n//<![CDATA[\n<%= #{var}_dom_ids.inspect %>.each(Zena.draggable)\n//]]>\n</script>"
        end
      elsif @context[:template_url]
        # render to produce a saved template
        id_hash = {:id=>"#{dom_id_from_template_url}.<%= #{node}.zip %>"}
        if @html_tag
          @html_tag_params.merge!(id_hash)
          out render_html_tag(expand_with)
        else
          out add_params(expand_with, id_hash)
        end
        if @params[:draggable] == 'true'
          out "<script type='text/javascript'>\n//<![CDATA[\nZena.draggable('#{dom_id_from_template_url}.<%= #{node}.zip %>')\n//]]>\n</script>"
        end
      else
        # TODO: make a single list ?
        @context[:list] = "[#{node}]"
        r_each
      end
    end
   
    def r_case
      out "<% if false -%>"
      out expand_with(:in_if=>true, :only=>['when', 'else', 'elsif'])
      out "<% end -%>"
    end
    
    # TODO: test
    def r_if
      cond = get_test_condition
      return "<span class='parser_error'>[if] condition error</span>" unless cond
      
      if cond == 'true'
        return expand_with(:in_if => false)
      elsif cond == 'false'
        if (descendants['else'] || descendants['elsif'])
          return expand_with(:in_if=>true, :only=>['else', 'elsif'])
        else
          @html_tag_done = true
          return ''
        end
      end
      
      out "<% if #{cond} -%>"
      out expand_with(:in_if=>false)
      out expand_with(:in_if=>true, :only=>['else', 'elsif'])
      out "<% end -%>"
    end
    
    def r_else
      if @context[:in_if]
        out "<% elsif true -%>"
        out expand_with(:in_if=>false)
      else
        ""
      end
    end
    
    def r_elsif
      return '' unless @context[:in_if]
      cond = get_test_condition
      return "<span class='parser_error'>[elsif] condition error</span>" unless cond
      out "<% elsif #{cond} -%>"
      out expand_with(:in_if=>false)
    end
    
    def r_when
      r_elsif
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
    
    def r_node
      @method = @params[:select] || 'node' # 'node' is for version.node
      r_unknown
    end
    
    def r_project
      do_var("#{node}.get_project", :node_class => Project)
    end

    def r_real_project
      do_var("#{node}.project", :node_class => Project)
    end
    
    def r_section
      do_var("#{node}.get_section", :node_class => Section)
    end

    def r_real_section
      do_var("#{node}.section", :node_class => Section)
    end
    
    def r_date
      select = @params[:select]
      case select
      when 'main'
        expand_with(:date=>"main_date")
      when 'now'
        expand_with(:date=>"Time.now")
      else
        if select =~ /^\d{4}-\d{1,2}-\d{1,2}$/
          expand_with(:date=>select)
        elsif date = find_stored(Date, select)
          begin
            d = Date.parse(select)
            expand_with(:date=>select)
          rescue
            "<span class='parser_error'>[date] invalid date (#{select}) should be 'YYYY-MM-DD'</span>"
          end
        elsif select =~ /^\[(.*)\]$/
          expand_with(:date=>"(#{node_attribute($1)} || main_date)")
        else
          "<span class='parser_error'>[date] bad parameter (#{select})</span>"
        end
      end
    end
    
    def r_current_date
      if @params[:tformat]
        format = _(@params[:tformat])
      elsif @params[:format]
        format = @params[:format]
      else
        format = _('long_date')
      end
      
      if @context[:trans]
        return "format_date(#{current_date}, #{format.inspect})"
      end
      
      out "<%= format_date(#{current_date}, #{format.inspect}) %>"
    end
    
    def r_javascripts
      list = @params[:list].split(',').map{|e| e.strip}
      helper.javascript_include_tag(*list)
    end
    
    def r_stylesheets
      list = @params[:list].split(',').map{|e| e.strip}
      list << {:media => @params[:media]} if @params[:media]
      helper.stylesheet_link_tag(*list)
    end
    
    def r_flash_messages
      type = @params[:show] || 'both'
      "<div id='messages'>" +
      if (type == 'notice' || type == 'both')
        "<% if flash[:notice] -%><div id='notice' class='flash' onclick='new Effect.Fade(\"error\")'><%= flash[:notice] %></div><% end -%>"
      else
        ''
      end + 
      if (type == 'error'  || type == 'both')
        "<% if flash[:error] -%><div id='error' class='flash' onclick='new Effect.Fade(\"error\")'><%= flash[:error] %></div><% end -%>"
      else
        ''
      end +
      "</div>"
    end
    
    # Shows a 'made with zena' link or logo. ;-) Thanks for using this !
    # TODO: test and add translation.
    # <r:zena show='logo'/> or <r:zena show='text'/> == <r:zena/>
    def r_zena
      if @params[:show] == 'logo'
        # FIXME
      else
        zena = "<a class='zena' href='http://zenadmin.org' title='zena #{Zena::VERSION::STRING} r#{Zena::VERSION::REV}'>zena</a>"
        case @params[:type]
        when 'riding'
          helper.send(:_, "riding %{zena}") % {:zena => zena}
        when 'peace'
          helper.send(:_, "in peace with %{zena}") % {:zena => zena}
        when 'garden'
          helper.send(:_, "a %{zen} garden") % {:zen => zena.sub('>zena<', '>zen<')}
        else
          helper.send(:_, "made with %{zena}") % {:zena => zena}
        end
      end
    end
    
    def r_design
      if @params[:by]
        by = "<a href='#{@params[:href]}'>#{@params[:by]}</a>"
      else
        by = expand_with(:trans => true)
      end
      unless name = @params[:skin]
        name = helper.instance_variable_get(:@controller).instance_variable_get(:@skin_name)
      end
      url = helper.instance_variable_get(:@controller).instance_variable_get(:@skin_link)
      skin = "<a class='skin' href='#{url}'>#{name}</a>"
      helper.send(:_, "%{skin} design by %{name}") % {:name => by, :skin => skin}
    end
    
    # creates a link. Options are:
    # :href (node, parent, project, root)
    # :tattr (translated attribute used as text link)
    # :attr (attribute used as text link)
    # <r:link href='node'><r:trans attr='lang'/></r:link>
    # <r:link href='node' tattr='lang'/>
    def r_link
      if @blocks.blank? || @params[:attr] || @params[:tattr] || @params[:trans] || @params[:text]
        text = get_text_for_erb
        text_mode = :erb
      else  
        text_mode = :raw
        text = expand_with
      end
      if @params[:href]
        unless lnode = find_stored(Node, @params[:href])
          href = ", :href=>#{@params[:href].inspect}"
        end
      else
        href = ''
      end
      # obj
      if node_class == Version
        lnode ||= "#{node}.node"
        url = ", :lang=>#{node}.lang"
      else
        lnode ||= node
        url = ''
      end
      if fmt = @params[:format]
        if fmt == 'data'
          fmt = ", :format => #{node}.c_ext"
        else
          fmt = ", :format => #{fmt.inspect}"
        end
      else
        fmt = ''
      end
      if mode = @params[:mode]
        mode = ", :mode => #{mode.inspect}"
      else
        mode = ''
      end
      if sharp = @params[:sharp]
        sharp = ", :sharp=>#{sharp.inspect}"
      else
        sharp = ''
      end
      if sharp_in = @params[:in]
        sharp_in = ", :sharp_in=>#{build_finder_for(:first, sharp_in)}"
      else
        sharp_in = ''
      end
      
      html_tags  = {}
      if @html_tag && @html_tag != 'a'
        # html attributes do not belong to sharp
        pre_space = ''
      else
        [:class, :id, :style].each do |sym|
          if value = @html_tag_params[sym] || @params[sym]
            html_tags[sym] = value
          end
        end
        pre_space = @space_before || ''
        @html_tag_done = true
      end
        
      if text_mode == :raw
        pre_space + "<a#{params_to_html(html_tags)} href='<%= node_link(:url_only=>true, :node=>#{lnode}#{href}#{url}#{sharp}#{sharp_in}#{fmt}#{mode}) %>'>#{text}</a>"
      else
        text = text.blank? ? '' : ", :text=>#{text}"
        pre_space + "<%= node_link(:node=>#{lnode}#{text}#{href}#{url}#{sharp}#{sharp_in}#{fmt}#{mode}#{params_to_erb(html_tags)}) %>"
      end
    end
    
    def r_img
      return unless node_kind_of?(Node)
      if @params[:src]
        img = build_finder_for(:first, @params[:src])
      else
        img = node
      end
      mode = @params[:mode] || 'std'
      res = "img_tag(#{img}, :mode=>#{mode.inspect}"
      [:class, :alt_src].each do |k|
        res  += ", :#{k}=>#{@params[k].inspect}" if @params[k]
      end
      res += ")"
      if @params[:link]
        link = build_finder_for(:first, @params[:link])
        res  = "node_link(:node=>#{link}, :text=>#{res})"
      end
      "<%= #{res} %>"
    end
    
    # TODO: test
    def r_calendar
      opts   = query_parameters(@params[:find  ] || 'news from project')
      opts.delete(:node_name)
      opts[:size]   = (@params[:size  ] || 'tiny'    )
      opts[:using]  = (@params[:using ] || 'event_at').gsub(/[^a-z_]/,'') # SQL injection security
      
      template_url = get_template_url
      out helper.save_erb_to_url(opts.inspect, template_url)
      
      "<div id='#{opts[:size]}cal'><%= calendar(:node=>#{node}, :date=>main_date, :template_url => #{template_url.inspect}) %></div>"
    end
    
    # part caching
    def r_cache
      kpath   = @params[:kpath]   || Page.kpath
      context = get_template_url
      out "<% #{cache} = Cache.with(visitor.id, visitor.group_ids, #{kpath.inspect}, #{helper.send(:lang).inspect}, #{context.inspect}) do capture do %>"
      out expand_with
      out "<% end; end %><%= #{cache} %>"
    end
    
    # use all other tags as relations
    # try to add 'conditions' without sql injection possibilities...
    # FIXME: 'else' clause has been removed, find a solution to put it back.
    def r_unknown
      if context = node_class.zafu_known_contexts[@method]
        if context.kind_of?(Array)
          # plural
          do_list( "#{node}.#{@method}", :node_class => context[0] )
        else
          # singular
          do_var(  "#{node}.#{@method}", :node_class => context )
        end
      elsif node_kind_of?(Node)
        if @params[:from] || @method =~ /\sfrom\s/ || Node.plural_relation?(@method)
          # plural
          do_list( build_finder_for(:all,   @method, @params) )
        else
          # singular
          do_var(  build_finder_for(:first, @method, @params) )
        end
      else
        "unknown relation (#{@method}) for #{node_class} class"
      end
    end
    
    # Prepare stylesheet and xml content for xsl-fo post-processor
    def r_fop
      return "<span class='parser_error'>[fop] missing 'stylesheet' argument</span>" unless @params[:stylesheet]
      # 1. get stylesheet text
      xsl_content, absolute_url, doc = self.class.get_template_text(@params[:stylesheet], @options[:helper], @options[:current_folder])
      return "<span class='parser_error'>[fop] stylesheet #{@params[:stylesheet].inspect} not found</span>" unless xsl_content
      
      template_url = (get_template_url.split('/')[0..-2] + ['_main.xsl']).join('/')
      helper.save_erb_to_url(xsl_content, template_url)
      out "<?xml version='1.0' encoding='utf-8'?>\n"
      out "<!-- xsl_id:#{doc[:id] } -->\n" if doc
      out expand_with
    end
    
    # Prepare content for LateX post-processor
    def r_latex
      out "% latex\n"
      # all content inside this will be informed to render for Latex output
      out expand_with(:output_format => 'latex')
    end
    
    # ================== HELPER METHODS ================
    
    # Create an sql query to open a new context (passes its arguments to HasRelations#build_find)
    def build_finder_for(count, rel, params=@params)
      if context = node_class.zafu_known_contexts[rel]
        klass = context.kind_of?(Array) ? context[0] : context
        
        if klass.ancestors.include?(Node)
          # ok
          if (count == :all && context.kind_of?(Array)) || (count == :first && !context.kind_of?(Array))
            return "#{node}.#{rel}"
          else
            # fail
            return 'nil'
          end
        end
      end
      
      rel ||= 'self'
      if (count == :first)
        if rel == 'self'
          return node
        elsif rel == 'main'
          return "@node"
        elsif rel == 'root'
          return "(secure(Node) { Node.find(#{current_site[:root_id]})})"
        elsif rel == 'visitor'
          return "visitor.contact"
        elsif rel =~ /^\d+$/
          return "(secure(Node) { Node.find_by_zip(#{rel.inspect})})"
        elsif node_name = find_stored(Node, rel)
          return node_name
        elsif rel[0..0] == '/'
          rel = rel[1..-1]
          return "(secure(Node) { Node.find_by_path(#{rel.inspect})})"
        end
      end
      
      sql_query = Node.build_find(count, query_parameters(rel, params))
      unless sql_query
        return "nil"
      end
      
      res = "#{node}.do_find(#{count.inspect}, \"#{sql_query}\"#{sql_query =~ /#{node}/ ? '' : ', true'})" # regexp to see if node is used. If not, we can ignore the source (use query even if #{node} is a new record).
      if params[:else]
        sql_query = Node.build_find(count, query_parameters(params[:else], params))
        if sql_query
          "(#{res} || #{node}.do_find(#{count.inspect}, \"#{sql_query}\"))"
        end
      else
        res 
      end
    end
    
    def query_parameters(rel, params=@params)
      # FIXME: could SQL injection be possible here ? (all params are passed to the 'find')
      relations    = [rel]
      conditions   = []
      query_params = {}
      
      if params[:from]
        if params[params[:from].to_sym]
          # <r:pages from='project' project='...'/>  is the same as <r:pages from='site' project='...'/>
          # <r:pages from='section' section='...'/>  is the same as <r:pages from='site' section='...'/>
          relations[0] << " from site"
        else
          relations[0] << " from #{params[:from]}"
        end
      end

      if params[:where]
        relations[0] << " where #{params[:where]}"
      end
      
      if params[:or]
        relations << params[:or]
        key_counter = 1
        while or_value = params["or#{key_counter}".to_sym]
          key_counter += 1
          relations << or_value
        end
      end
      
      if order = params[:order]
        if order == 'random'
          query_params[:order] = 'RAND()'
        elsif order =~ /\A(\w+)( ASC| DESC|)\Z/
          query_params[:order] = order
        else
          # ignore
        end
      end
      
      [:limit, :offset].each do |k|
        next unless params[k]
        query_params[k] = params[k].to_i.to_s
      end
      
      
      # FIXME: stored should be clarified and managed in a single way through links and contexts.
      # <r:void store='foo'>...
      # <r:link href='foo'/>
      # <r:pages from='foo'/>
      # <r:pages from='site' project='foo'/>
      # <r:img link='foo'/>
      # ...
      if value = params[:author]
        if stored = find_stored(User, value)
          conditions << "user_id = '\#{#{stored}.id}'"
        elsif value == 'current'
          conditions << "user_id = '\#{#{node}[:user_id]}'"
        elsif value == 'visitor'
          conditions << "user_id = '\#{visitor[:id]}'"
        elsif value =~ /\A\d+\Z/
          conditions << "user_id = '#{value.to_i}'"
        elsif value =~ /\A[\w\/]+\Z/
          # TODO: path, not implemented yet
        end
      end
      
      if value = params[:project]
        if stored = find_stored(Node, value)
          conditions << "project_id = '\#{#{stored}.get_project_id}'"
        elsif value == 'current'
          conditions << "project_id = '\#{#{node}.get_project_id}'"
        elsif value =~ /\A\d+\Z/
          conditions << "project_id = '#{value.to_i}'"
        elsif value =~ /\A[\w\/]+\Z/
          # TODO: path, not implemented yet
        end
      end
      
      if value = params[:section]
        if stored = find_stored(Node, value)
          conditions << "section_id = '\#{#{stored}.get_section_id}'"
        elsif value == 'current'
          conditions << "section_id = '\#{#{node}.get_section_id}'"
        elsif value =~ /\A\d+\Z/
          conditions << "section_id = '#{value.to_i}'"
        elsif value =~ /\A[\w\/]+\Z/
          # not implemented yet
        end
      end
      
      [:updated, :created, :event, :log].each do |k|
        if value = params[k]
          # current, same are synonym for 'today'
          conditions << Node.connection.date_condition(value,"#{k}_at",current_date)
        end
      end

      query_params[:conditions] = conditions.join(' AND ') if conditions != []
      query_params[:relations ] = relations.map { |r| r.gsub('&gt;', '>').gsub('&lt;', '<')}
      query_params[:node_name ] = node
      query_params
    end
    
    # helpers
    # get current output format
    def output_format
      @context[:output_format] || 'html'
    end
    
    # find the current node name in the context
    def node
      @context[:node] || '@node'
    end
    
    def current_date
      @context[:date] || 'main_date'
    end
    
    def var
      return @var if @var
      if node =~ /^var(\d+)$/
        @var = "var#{$1.to_i + 1}"
      else
        @var = "var1"
      end
    end
    
    def cache
      return @cache if @cache
      if @context[:cache] =~ /^cache(\d+)$/
        @cache = "cache#{$1.to_i + 1}"
      else
        @cache = "cache1"
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
    
    # TODO: replace symbols by real classes
    def node_class
      @context[:node_class] || Node
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
    
    def node_kind_of?(ancestor)
      node_class.ancestors.include?(ancestor)
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
    
    def do_var(var_finder=nil, opts={})
      if var_finder == 'nil'
        out "<% if nil -%>"
      elsif var_finder
        out "<% if #{var} = #{var_finder} -%>"
      end
      
      res = expand_with(opts.merge(:node=>var, :in_if => false))
      
      if var_finder
        res += expand_with(opts.merge(:in_if => true, :only => ['else', 'elsif']))
      end
      out render_html_tag(res)
      out "<% end -%>" if var_finder
    end
    
    def do_list(list_finder=nil, opts={})
      
      @context.delete(:template_url) # should not propagate
      @context.delete(:make_form)    # should not propagate
      
      # real class (Node, Version, ...)
      node_class = opts[:node_class] || self.node_class
      
      if (each_block = descendant('each')) && (descendant('edit') || descendant('add') || descendant('add_document') || (descendant('swap') && descendant('swap').parent.method != 'group'))
        # ajax, build template. We could merge the following code with 'r_group'.
        add_block  = descendant('add')
        form_block = descendant('form') || each_block
        if list_finder
          out "<% if (#{list_var} = #{list_finder}) || (#{node}.can_write? && #{list_var}=[]) -%>"
        end
        
        template_url = each_block.get_template_url(@context)
        
        # should we publish ?
        publish_after_save ||= form_block ? form_block.params[:publish] : nil
        publish_after_save ||= descendant('edit') ? descendant('edit').params[:publish] : nil
        
        # class name for erb form
        klass       = add_block  ? add_block.params[:klass]  : nil
        klass     ||= form_block ? form_block.params[:klass] : nil
        
        # 'r_add' needs the form when rendering. Send with :form.
        res = expand_with(opts.merge(:list=>list_var, :form=>form_block, :publish_after_save => publish_after_save, :no_form=>true, :template_url=>template_url, :klass => klass, :in_if => (list_finder ? true : false) ))
        out render_html_tag(res)
        out "<% end -%>" if list_finder

        # TEMPLATE ========
        template_node = "@#{base_class.to_s.underscore}"
        template      = expand_block(each_block, :list=>false, :node=>template_node, :node_class => node_class, :klass => klass, :template_url=>template_url)
        out helper.save_erb_to_url(template, template_url)
        
        # FORM ============
        form_url = "#{template_url}_form"
        if each_block != form_block
          form = expand_block(form_block, :node=>template_node, :node_class => node_class, :klass => klass, :template_url=>template_url, :add=>add_block, :publish_after_save => publish_after_save) 
        else
          form = expand_block(form_block, :node=>template_node, :node_class => node_class, :klass => klass, :template_url=>template_url, :add=>add_block, :make_form=>true, :no_edit=>true, :publish_after_save => publish_after_save)
        end
        out helper.save_erb_to_url(form, form_url)
      else
        # no form, render, edit and add are not ajax
        if list_finder
          if descendant('add') || descendant('add_document')
            out "<% if (#{list_var} = #{list_finder}) || (#{node}.can_write? && #{list_var}=[]) -%>"
          elsif list_finder != 'nil'
            out "<% if #{list_var} = #{list_finder} -%>"
          else
            out "<% if nil -%>"
          end
        end
        res = expand_with(opts.merge(:list=>list_var, :in_if => (list_finder ? true : false)))
        out render_html_tag(res)
        out "<% end -%>" if list_finder
      end
    end
    
    def _(text)
      helper.send(:_,text)
    end
    
    # Unique DOM identifier for this tag
    def dom_id(context = @context)
      @dom_id ||= unique_name(context)
    end

    # Unique template_url, ending with dom_id
    def get_template_url(context = @context)
      "#{@options[:included_history][0].split('::')[0]}/#{dom_id(context)}"
    end
    
    # Return the DOM identifier from the template url
    def dom_id_from_template_url(url = @context[:template_url])
      url.split('/').last
    end

    # Return a different name on each call
    def unique_name(context = @context)
      root.next_name_index((context[:name] || 'list')).gsub(/[^\d\w\/]/,'_')
    end
    
    def next_name_index(key)
      @next_name_index ||= {}
      if @next_name_index[key]
        @next_name_index[key] += 1
        key + @next_name_index[key].to_s
      else
        @next_name_index[key] = 0
        key
      end
    end
       
    def add_params(text, opts={})
      text.sub(/\A([^<]*)<(\w+)( [^>]+|)>/) do
        # we must set the first tag id
        before = $1
        tag = $2
        params = parse_params($3)
        opts.each do |k,v|
          next unless v
          params[k] = v
        end
        "#{before}<#{tag}#{params_to_html(params)}>"
      end
    end
    
    def get_test_condition(node = self.node, params = @params)
      if klass = params[:kind_of]
        "#{node}.vkind_of?(#{klass.inspect})"
      elsif klass = params[:klass]
        begin Module::const_get(klass) rescue "NilClass" end
        "#{node}.klass == #{klass.inspect}"
      elsif status = params[:status]
        "#{node}.version.status == #{Zena::Status[status.to_sym]}"
      elsif lang = params[:lang]
        "#{node}.version.lang == #{lang.inspect}"
      elsif can  = params[:can]
        # TODO: test
        case can
        when 'write', 'edit'
          "#{node}.can_write?"
        when 'drive', 'publish'
          "#{node}.can_drive?"
        end
      elsif test = params[:test]  
        if test =~ /\s/
          value1, op, value2 = test.split(/\s+/)
          allOK = value1 && op && value2
          toi   = ( op =~ /\&/ )
          if ['==', '!=', '&gt;', '&gt;=', '&lt;', '&lt;='].include?(op)
            op = op.gsub('&gt;', '>').gsub('&lt;', '<')
          else
            allOK = false
          end
          if allOK
            value1, value2 = [value1, value2].map do |e|
              if e =~ /\[(\w+)\]/
                v = node_attribute($1)
                v = "#{v}.to_i" if toi
                v
              else
                if toi
                  e.to_i
                else
                  e.inspect
                end
              end
            end
          end
          allOK ? "#{value1} #{op} #{value2}" : nil
        elsif test =~ /\[([^\]]+)\]/
          '!' + node_attribute($1, :node => node) + '.blank?'
        else
          # bad test condition.
          'false'
        end
      elsif node_cond = params[:node]
        if node_kind_of?(Node)
          case node_cond
          when 'self'
            "#{node}[:id] == @node[:id]"
          when 'parent'
            "#{node}[:id] == @node[:parent_id]"
          when 'project'
            "#{node}[:id] == @node[:section_id]"
          when 'ancestor'
            "@node.fullpath =~ /\\A\#{#{node}.fullpath}/"
          else
            nil
          end
        else
          nil
        end  
      elsif in_tag = params[:in]
        if @context["in_#{in_tag}".to_sym] || ancestors.include?(in_tag)
          'true'
        else
          'false'
        end
      else
        nil
      end
    end
    
    # Block visibility of descendance with 'do_list'.
    def public_descendants
      if ['do_list'].include?(@method)
        {}
      else
        super
      end
    end
    
    def node_attribute(attribute, opts={})
      att_node = opts[:node]       || node
      klass    = opts[:node_class] || node_class
      res = if klass.ancestors.include?(Node)
        attribute = attribute.gsub(/\A(|[\w_]+)id(s?)\Z/, '\1zip\2') unless attribute =~ /\Ad_/
        if ['url','path'].include?(attribute)
          # pseudo attribute 'url'
          params = {}
          params[:mode]   = @params[:mode]   if @params[:mode]
          params[:format] = @params[:format] if @params[:format]
          "zen_#{attribute}(#{node}#{params_to_erb(params)})"
        else
          Node.zafu_attribute(att_node, attribute)
        end
      elsif klass.ancestors.include?(Version) && Version.zafu_readable?(attribute)
        "#{att_node}.#{attribute}"
      elsif klass.ancestors.include?(DataEntry) && DataEntry.zafu_readable?(attribute)
        "#{att_node}.#{attribute}"
      else
        # unknown class, resolve at runtime
        "#{att_node}.zafu_read(#{attribute.inspect})"
      end
      
      if opts[:else]
        "(#{res} || #{node_attribute(opts[:else])})"
      else
        res
      end
    end
    
    def render_html_tag(text,*append)
      append ||= []
      return text if @html_tag_done
      set_params  = {}
      if_params   = {}
      @params.each do |k,v|
        if k.to_s =~ /^t?set_/
          set_params[k] = v
        end
      end
      tag_class = @html_tag_params[:class] || @params[:class]
      @params.each do |k,v|
        if k.to_s =~ /^(.+)_if$/
          klass = $1
          cond = if node_kind_of?(Node)
              if v =~ /=|\[/
                get_test_condition((@method == 'each' ? var : node), :test => v)
              elsif v =~ /^(.+)\s(.*)$/
                get_test_condition((@method == 'each' ? var : node), $1.to_sym => $2)
              else
                get_test_condition((@method == 'each' ? var : node), :node => v)
              end
            else
              nil
            end
          if cond
            append << "<%= #{cond} ? \" class='#{klass}'\" : \"#{tag_class ? " class='#{tag_class}'" : ""}\" %>"
            @html_tag_params.delete(:class)
          end
        end
      end
      
      @html_tag = 'div' if !@html_tag && (set_params != {} || @html_tag_params != {})
      
      bak = @html_tag_params.dup
      res_params = {}
      set_params.merge(@html_tag_params).each do |k,v|
        if k.to_s =~ /^(t?)set_(.+)$/
          key   = $2
          trans = $1 == 't'
          static = true
          value = v.gsub(/\[([^\]]+)\]/) do
            static = false
            node_attr = $1
            
            use_node  = @var || node
            if node_attr =~ /([^\.]+)\.(.+)/
              node_name = $1
              node_attr = $2
              if use_node = find_stored(Node, node_name)
                res = node_attribute(node_attr, :node => use_node )
              elsif node_name = 'main'
                res = node_attribute(node_attr, :node => '@node', :node_class => Node )
              else
                res = "bad node_name #{use_node.inspect}"
              end
            else
              # normal node_attribute
              res = node_attribute(node_attr, :node => use_node )
            end
            
            if trans
              "\#{#{res}}"
            else
              "<%= #{res} %>"
            end
          end
          
          if trans
            if static
              value = ["'#{_(value)}'"]            # array so it is not escaped on render
            else
              value = ["'<%= _(\"#{value}\") %>'"] # array so it is not escaped on render
            end
          end
          res_params[key.to_sym] = value
        else
          res_params[k] = v unless res_params[k]
        end
      end
      @html_tag_params = res_params
      res = super(text,*append)
      @html_tag_params = bak
      res
    end
    
    def get_text_for_erb(params = @params)
      if params[:attr]
        text = "#{node_attribute(params[:attr])}"
      elsif params[:tattr]
        text = "_(#{node_attribute(params[:tattr])})"
      elsif params[:trans]
        text = _(params[:trans]).inspect
      elsif params[:text]
        text = params[:text].inspect
      elsif @blocks != []
        res  = []
        text = ""
        static = true
        @blocks.each do |b|
          # FIXME: this is a little too hacky
          if b.kind_of?(String)
            res  << b.inspect
            text << b
          elsif ['show', 'img'].include?(b.method)
            res << expand_block(b, :trans=>true)
            static = false
          elsif ['rename_asset', 'trans'].include?(b.method)
            # FIXME: if a trans contains non-static: static should become false
            res  << expand_block(b).inspect
            text << expand_block(b)
          else
            # ignore
          end
        end
        if static
          # "just plain text"
          text = text.inspect
        else
          # function(...) + "blah" + function()
          text = res.join(' + ')
        end
      else
        text = nil
      end
      text
    end
    
    def get_input_params(params = @params)
      res = {}
      unless res[:name] = (params[:name] || params[:date])
        return [{}, nil]
      end
      
      if res[:name] =~ /\A([\w_]+)\[(.*?)\]/
        attribute = $2
        res[:id]   = "#{$1}_#{$2}"
      else
        attribute = res[:name]
        res[:name] = "#{base_class.to_s.underscore}[#{attribute}]"
        res[:id]   = "#{@context[:template_url].split('/').last}_#{attribute}" if @context[:template_url]
      end
      
      if @context[:in_add]
        res[:value] = (params[:value] || params[:set_value]) ? ["'#{params[:value]}'"] : ["''"]
      else
        res[:value] = attribute ? ["'<%= #{node_attribute(attribute)} %>'"] : ["''"]
      end
      return [res, attribute]
    end
    
    def find_stored(klass, key)
      @context["#{klass}_#{key}"]
    end
    
    def set_stored(klass, key, obj)
      @context["#{klass}_#{key}"] = obj
    end

    # transform a 'show' tag into an input field.
    def make_input(params = @params)
      input, attribute = get_input_params(params)
      return "<span class='parser_error'>[input] missing 'name'</span>" unless attribute
      return '' if attribute == 'parent_id' # set with 'r_form'
      return '' if ['url','path'].include?(attribute) # cannot be set with a form
      if params[:date]
      input_id = @context[:template_url] ? ", :id=>#{(@context[:template_url].split('/').last.to_s + '_' + attribute.to_s).inspect} + #{node}.zip.to_s" : ''
        return "<%= date_box('#{base_class.to_s.underscore}', #{params[:date].inspect}#{input_id}) %>"
      end
      input_id = @context[:template_url] ? " id='#{@context[:template_url].split('/').last}_#{attribute}'" : ''
      "<input type='#{params[:type] || 'text'}'#{input_id} name='#{input[:name]}' value=#{input[:value]}/>"
    end
    
    # transform a 'zazen' tag into a textarea input field.
    def make_textarea(params)
      return "<span class='parser_error'>[textarea] missing 'name'</span>" unless name = params[:name]
      if name =~ /\A([\w_]+)\[(.*?)\]/
        attribute = $2
      else
        attribute = name
        name = "#{base_class.to_s.underscore}[#{attribute}]"
      end
      return '' if attribute == 'parent_id' # set with 'r_form'
      
      if @context[:in_add]
        value = ''
      else
        value = attribute ? "<%= #{node_attribute(attribute)} %>" : ""
      end
      "<textarea name='#{name}'>#{value}</textarea>"
    end
  end
end

# FIXME: this should be in a separate file "adapters_ext"
module ActiveRecord
  module ConnectionAdapters
    class MysqlAdapter
      
      # ref_date can be a string ('2005-05-03') or ruby ('Time.now'). It should not come uncleaned from evil web.
      def date_condition(date_cond, field, ref_date='today')
        if date_cond == 'today' || ref_date == 'today'
          ref_date = 'now()'
        elsif ref_date =~ /^\d{4}-\d{1,2}-\d{1,2}$/
          ref_date = "'#{ref_date}'"
        else
          ref_date = "'\#{#{ref_date}.strftime('%Y-%m-%d')}'"
        end
        case date_cond
        when 'today', 'current', 'same'
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
