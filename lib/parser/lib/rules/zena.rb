=begin
Thoughts for ajax related stuff cleanup (dom_id, erb_dom_id, ...)

When we open a list context:
- we change the context_dom_id => unique name => "page"

When we open a single context (do_var, each, block):
- we change the context_dom_id => unique name with id => "page_{parent_id}"

Any 'id' is set with:
- "{context_dom_id}_{id}"  => 'page_34' (if not in list) or 'page_12_34' if in list.


List in list (initial node zip = 12):
                             context_dom_id    dom_id          (context_erb_dom_id, erb_dom_id)
<ul>                         page_12           page_12         [pages in='site']  new unique name
  <li id='page_12_13'>       page_12           page_12_13      [each]   expand_with(:context_dom_id => 'page_13')
    <ul>                     page_13
      <li id='page_13_23'/>  page_13           page_13_23      [each]
      <li id='page_13_24'/>  page_13           page_13_24      [each]
      <li id='page_13_25'/>  page_13           page_13_25      [each]
    </ul>
  </li>
  <li id='page_12_14'>       page_12           page_12_14      [each]   expand_with(:context_dom_id => 'page_14')
    <ul>
      <li id='page_14_23'/>  page_14           page_14_23      [each]   expand_with(:context_dom_id => 'page_23')
      <li id='page_14_27'/>  page_14           page_14_27      [each]   ...
    </ul>
  </li>
</ul>

<div id='page1_12'>          page1_12          page1_12        [block]    new unique name
  <ul>
    <li id='page1_12_24'/>   page1_12          page1_12_24     [each]
    <li id='page1_12_32'/>   page1_12          page1_12_32     [each]
  </ul>
</div>
=end

require 'yaml'

module Zena
  module Rules
    def start(mode)
      super
      if @method =~ /^\[(.*)\]$/
        # do='[text]
        @method = 'show'
        @params[:attr_or_date] = $1
      elsif @method =~ /^\{(.*)\}$/
        # do='{v_text}'
        @method = 'zazen'
        @params[:attr] = $1
      elsif @method =~ /\A(\w+)\s+(\w+)\s+(.+)$/
        # 'pages where name ...'
        @params[:select] = @method
        @method = 'context'
      end
      
      if @method == 'with' || self.respond_to?("r_#{@method}")
        # ok
      else
        @params[:select] = @method
        @method = 'context'
      end
    end
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
    inline_methods :login_link, :visitor_link, :search_box, :show_menu, :show_path, :lang_links
    direct_methods :uses_calendar

    def before_render
      return unless super
      
      @var = nil # reset var counter
      
      if key = @params[:store]
        set_stored(Node, key, node)
      end
      
      if key = @params[:store_date]
        set_stored(Date, key, current_date)
      end
      @anchor_param = @params[:anchor]
      
      true
    end
    
    def do_method(sym)
      method = sym
      pre, post = '', ''
      
      # do we need recursion ?
      inc = descendant('include')
      if inc && inc.params[:part] == @name
        @context["#{@name}_method".to_sym] = method_name = template_url[1..-1].gsub(/[\/-]/,'_')
        pre << "<% def #{method_name}(depth, node, list); return '' if depth > #{inc.params[:depth] ? [inc.params[:depth].to_i,30].min : 5}; _erbout = '' -%>"
        post << "<% _erbout; end -%><%= #{method_name}(0,#{node},#{list || "[#{node}]"}) %>"
        @context[:node] = 'node'
        @context[:list] = 'list'
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
          end
        end
        res =  "<#{@html_tag || 'div'} class='zazen'>#{res}</#{@html_tag || 'div'}>" if [:r_summary, :r_text].include?(sym)
      end
      
      
      res ||= super(method)
      "#{pre}#{res}#{post}"
    end
    
    
    def after_render(text)
      if @anchor_param
        @params[:anchor] = @anchor_param # set back in case of double rendering so it is computed again
        res = r_anchor + super
      else
        res = super
      end
      res
    end
    
    # Our special version of r_expand_with tag with "set_" parsing.
    def r_expand_with
      hash = {}
      @params.each do |k,v|
        if k.to_s =~ /^set_(.+)$/
          # TODO: DRY with render_html_tag
          k   = $1
          value, static = parse_attributes_in_value(v, :erb => false)
          hash["exp_#{k}"] = static ? value.inspect : "\"#{value}\""
        else
          hash["exp_#{k}"] = v.inspect
        end
      end
      @params = {}
      expand_with(hash)
    end
    
    def r_show
      if attr_or_date = @params[:attr_or_date]
        # using [var] shortcut. Can be either a date or an attribute/var
        if attr_or_date == 'current_date' || attr_or_date =~ /_at$/
          @params[:date] = attr_or_date
        else
          @params[:attr] = attr_or_date
        end
      end

      if var_name = @params[:var]
        return parser_error("var #{@params[:var].inspect} not set") unless @context[:vars] && @context[:vars].include?(var_name)
        attribute_method = "set_#{var_name}"
      elsif @params[:eval]
        return unless attribute_method = parse_eval_parameter(@params[:eval])
      elsif @params[:tattr]
        attribute_method = "_(#{node_attribute(@params[:tattr], :else=>@params[:else], :default=>@params[:default])})"
      elsif @params[:attr]
        attribute_method = node_attribute(@params[:attr], :else=>@params[:else], :default=>@params[:default])
      elsif p = @params[:param]
        return "<%= params[#{p.to_sym.inspect}] %>"
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
        
        tz   = ''
        lang = ''
        if tz_name = @params[:time_zone]
          tz_list = @params.reject {|k,v| !(k.to_s =~ /^time_zone\d*$/)}.to_a.sort {|a,b| a[0].to_s <=> b[0].to_s }.map do |k,tz_name|
            if tz_name =~ /^\[(\w+)\]$/
              node_attribute($1)
            else
              begin
                TZInfo::Timezone.get(tz_name)
              rescue TZInfo::InvalidTimezoneIdentifier
                return parser_error("invalid timezone #{tz_name.inspect}")
              end
              tz_name.inspect
            end
          end
          tz = ", #{tz_list.join(' || ')}"
        end
        if lang = @params[:lang]
          tz = ', nil' if tz == ''
          lang = ", #{lang.inspect}"
        end
        attribute_method = "format_date(#{node_attribute(@params[:date])}, #{format.inspect}#{tz}#{lang})"
      elsif @context[:trans]
        # error
        return "no attribute for 'show'".inspect
      else  
        return parser_error("missing attribute")
      end
      
      if !@params[:date] && fmt = @params[:format]
        begin
          # test argument
          sprintf(fmt, 123.45)
        rescue ArgumentError
          return parser_error("incorect format #{fmt.inspect}")
        end
        if fmt =~ /%[\d\.]*f/
          modifier = ".to_f"
        elsif fmt =~ /%[\d\.]*i/
          modifier = ".to_i"
        else
          modifier = ''
        end
        
        if @params[:zero] == 'hide'
          attribute_method = "sprintf_unless_zero(#{fmt.inspect}, #{attribute_method}#{modifier})"
        else
          attribute_method = "sprintf(#{fmt.inspect}, #{attribute_method}#{modifier})"
        end
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
          regexp_ok = begin
            output = StringIO.open('','w')
            $stderr = output
            re = /#{key}/
            output.string !~ /warning:/
          rescue
            false
          ensure
            $stderr = STDERR
            false
          end
          
          if regexp_ok
            attribute_method = "#{attribute_method}.to_s.gsub(/#{key}/,#{value.inspect})"
          else
            # invalid regexp
            return parser_error("invalid gsub #{gsub.inspect}")
          end
        else
          # error
          return parser_error("invalid gsub #{gsub.inspect}")
        end
      end
      
      if @params[:actions]
        actions = "<%= node_actions(:node=>#{node}#{params_to_erb(:actions=>@params[:actions], :publish_after_save=>(@params[:publish] == 'true'))}) %>"
      else
        actions = ''
      end
      
      attribute = @params[:attr] || @params[:tattr] || @params[:date]
      
      if (@params[:edit_preview] || @params[:ep]) == 'true'
        @html_tag_params[:id] = "#{attribute}#{erb_node_id}"
        @html_tag ||= 'span'
      end
      
      if @params[:edit] == 'true' && !['url','path'].include?(attribute)
        "<% if #{node}.can_write? -%><span class='show_edit' id='#{erb_dom_id("_#{attribute}")}'>#{actions}<%= link_to_remote(#{attribute_method}, :url => edit_node_path(#{node_id}) + \"?attribute=#{attribute}&dom_id=#{dom_id("_#{attribute}")}#{@params[:publish] == 'true' ? '&publish=true' : ''}\", :method => :get) %></span><% else -%>#{actions}<%= #{attribute_method} %><% end -%>"
      else
        "#{actions}<%= #{attribute_method} %>"
      end
    end
    
    def r_zazen
      attribute = @params[:attr] || @params[:tattr]
      limit  = @params[:limit] ? ", :limit=>#{@params[:limit].to_i}" : ""
      if @context[:trans]
        # TODO: what do we do here with dates ?
        return "#{node_attribute(attribute)}"
      elsif @params[:tattr]
        return "<%= zazen(_(#{node_attribute(attribute)})#{limit}, :node=>#{node(Node)}) %>"
      elsif @params[:attr]
        if output_format == 'html'
          res = "<%= zazen(#{node_attribute(attribute)}#{limit}, :node=>#{node(Node)}) %>"
        else
          return "<%= zazen(#{node_attribute(attribute)}#{limit}, :node=>#{node(Node)}, :output=>#{output_format.inspect}) %>"
        end
      elsif @params[:date]
        # date can be any attribute v_created_at or updated_at etc.
        # TODO format with @params[:format] and @params[:tformat] << translated format
      else
        # error
      end
      
      @html_tag ||= 'div'
      
      add_html_class('zazen')
      
      if (@params[:edit_preview] || @params[:ep]) == 'true'
        @html_tag_params[:id] = "#{attribute}#{erb_node_id}"
      end
      
      if @params[:edit] == 'true' && !['url','path'].include?(attribute)
        edit_text = _('edit')
        @html_tag_params[:id] = erb_dom_id("_#{attribute}")
        res = "<% if #{node}.can_write? -%><span class='zazen_edit'><%= link_to_remote(#{edit_text.inspect}, :url => edit_node_path(#{node_id}) + \"?attribute=#{attribute}&dom_id=#{dom_id("_#{attribute}")}#{@params[:publish] == 'true' ? '&publish=true' : ''}&zazen=true\", :method => :get) %></span><% end -%>#{res}"
      else
        res
      end
    end
    
    # TODO: test, rename ?
    def r_search_results
      do_list("@nodes")
    end
    
    
    def r_set
      return parser_error("'var' missing") unless var_name = @params[:var]
      return parser_error("bad value for 'var' (#{var_name.inspect})") unless var_name =~ /^[a-zA-Z_]+$/
      return '' unless @context[:set]
      if @params[:value]
        out "<% set_#{var_name} = #{@params[:value].inspect} -%>"
      elsif @params[:eval]
        return unless eval_string = parse_eval_parameter(@params[:eval])
        out "<% set_#{var_name} = #{eval_string} -%>"
      else
        out "<% set_#{var_name} = capture do %>"
        out expand_with(:set => false) # do not propagate
        out "<% end -%>"
      end
    end
    
    
    # TODO: write a test (please)
    # FIXME: we should use a single way to change a whole context into a template (applies to 'each', 'form', 'block'). Then 'swap' could use the 'each' block.
    # Define a block of elements to be used by ajax calls (edit/filter)
    def r_block
      if @context[:block] == self
        # called from self (storing template)
        @context.reject! do |k,v|
          # FIXME: reject all stored elements in a  better way then this
          k.kind_of?(String) && k =~ /\ANode_\w/
        end
        @html_tag_done = false
        @html_tag_params.merge!(:id=>erb_dom_id)
        @context[:scope_node] = node if @context[:scope_node]
        out expand_with(:node => node)
        if @method == 'drop' && !@context[:make_form]
          out drop_javascript
        end
      else
        if parent.method == 'each' && @method == parent.single_child_method
          # use parent as block
          # FIXME: will not work with block as distant target...
          # do nothing
        else
          @html_tag ||= 'div'
          new_dom_scope
          
          unless @context[:make_form]
            # STORE TEMPLATE ========

            context_bak = @context.dup # avoid side effects when rendering the same block
            ignore_list = @method == 'block' ? ['form'] : [] # do not show the form in the normal template of a block
            template    = expand_block(self, :block=>self, :list=>false, :saved_template=>true, :ignore => ignore_list)
            @context    = context_bak
            @result     = ''
            out helper.save_erb_to_url(template, template_url)

            # STORE FORM ============
            if edit = descendant('edit')
              publish_after_save = (edit.params[:publish] == 'true')
              if form = descendant('form')
                # USE BLOCK FORM ========
                form_text = expand_block(form, :saved_template=>true, :publish_after_save => publish_after_save)
              else
                # MAKE A FORM FROM BLOCK ========
                form = self.dup
                form.method = 'form'
                form_text = expand_block(form, :make_form => true, :list => false, :saved_template => true, :publish_after_save => publish_after_save)
              end
              out helper.save_erb_to_url(form_text, form_url)
            end
          end

          # RENDER
          @html_tag_done = false
          @html_tag_params.merge!(:id=>erb_dom_id)
        end
        
        out expand_with
        if @method == 'drop' && !@context[:make_form]
          out drop_javascript
        end
      end
    end
    
    # TODO: test
    def r_filter
      if upd = @params[:update]
        return unless block = find_target(upd)
      else
        return parser_error("missing 'block' in same parent") unless parent && block = parent.descendant('block')
      end
      return parser_error("cannot use 's' as key (used by start_node)") if @params[:key] == 's'
      out "<%= form_remote_tag(:url => zafu_node_path(#{node_id}), :method => :get, :html => {:id => \"#{dom_id}_f\"}) %><div class='hidden'><input type='hidden' name='t_url' value='#{block.template_url}'/><input type='hidden' name='dom_id' value='#{block.erb_dom_id}'/>#{start_node_s_param(:input)}</div><div class='wrapper'>"
      if @blocks == []
        out "<input type='text' name='#{@params[:key] || 'f'}' value='<%= params[#{(@params[:key] || 'f').to_sym.inspect}] %>'/>"
      else
        out expand_with(:in_filter => true)
      end
      out "</div></form>"
      if @params[:live] || @params[:update]
        out "<%= observe_form( \"#{dom_id}_f\" , :method => :get, :frequency  =>  1, :submit =>\"#{dom_id}_f\", :url => zafu_node_path(#{node_id})) %>"
      end
    end
    
    # swap an attribute
    # TODO: test
    def r_swap      
      if upd = @params[:update]
        if upd == '_page'
          block = nil
        elsif block = find_target(upd)
          # ok
          if ancestor('block') || ancestor('each')
            upd_both = '&upd_both=true'
          else
            upd_both = ''
          end
        else
          return
        end
      elsif ancestor('block') || ancestor('each')
        # ancestor: ok
        block = self
      elsif parent && block = parent.descendant('block')
        # sibling: ok
        upd_both = ''
      else
        return parser_error("missing 'block' in same parent")
      end
      states = ((@params[:states] || 'todo, done') + ' ').split(',').map(&:strip)
      
      query_params = "node[#{@params[:attr]}]=\#{#{states.inspect}[ ((#{states.inspect}.index(#{node_attribute(@params[:attr])}.to_s) || 0)+1) % #{states.size}]}#{upd_both}"
      
      
      out link_to_update(block, :query_params => query_params, :method => :put, :html_params => get_html_params(@params, :link))
    end
    
    def r_load
      if dict = @params[:dictionary]
        dict_content, absolute_url, doc = self.class.get_template_text(dict, @options[:helper], @options[:current_folder])
        return parser_error("dictionary #{dict.inspect} not found") unless doc
        @context[:dict] ||= {}
        begin
          definitions = YAML::load(dict_content)
          definitions['translations'].each do |elem|
            @context[:dict][elem[0]] = elem[1]
          end
        rescue
          return parser_error("invalid dictionary content #{dict.inspect}")
        end
      else
        return parser_error("missing 'dictionary'")
      end
      expand_with
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
        _(text)
      else
        "<%= _(#{text}) %>"
      end
    end
    
    alias r_t r_trans
        
    def r_anchor(obj=node)
      "<a name='#{anchor_name(@anchor_param, obj)}'></a>"
    end
    
    def anchor_name(p, obj=node)
      if p =~ /\[(.+)\]/
        "<%= #{node_attribute($1)} %>"
      else
        "#{base_class.to_s.underscore}#{erb_node_id(obj)}"
      end
    end
    
    def r_content_for_layout
      "<% if @content_for_layout -%><%= @content_for_layout %><% else -%>" +
      expand_with +
      "<% end -%>"
    end
    
    def r_title_for_layout
      "<% if @title_for_layout -%><%= @title_for_layout %><% elsif @node && !@node.new_record? -%><%= @node.rootpath %><% elsif @node.parent -%><%= @node.parent.rootpath %><% else -%>" +
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
      elsif node_kind_of?(Node)
        node = self.node
      else
        return parser_error('title','only works with nodes')
      end
      title_params = {}
      
      title_params[:check_lang] = @params[:check_lang] if @params.include?(:check_lang)
      
      if @params[:link]
        value, static = parse_attributes_in_value(@params[:link], :erb => false)
        link_param = ", :link=>\"#{value}\""
      else
        link_param = ''
      end
      
      res = "<%= show_title(:node=>#{node}#{link_param}#{params_to_erb(title_params)}"
      if @params[:text]
        res << ", :text=>#{@params[:text].inspect}"
      elsif @params[:attr]
        res << ", :text=>#{node_attribute(@params[:attr])}"
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
        @html_tag ||= 'span'
        add_html_class("s<%= #{node}.version.status %>")
      end
      res
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
      
      @html_tag ||= 'div'
      
      if @html_tag_params[:id]
        # add a sub-div
        pre  = "<div id='v_text#{erb_node_id}'>"
        post = "</div>"
      else
        pre = post = ''
        @html_tag_params[:id] = "v_text#{erb_node_id}"
      end
      
      add_html_class('zazen')
      
      unless @params[:empty] == 'true'
        out "#{pre}<% if #{node}.kind_of?(TextDocument); l = #{node}.content_lang -%>"
        out "<%= zazen(\"<code\#{l ? \" lang='\#{l}'\" : ''} class=\\'full\\'>\#{#{text}}</code>\") %>"
        out "<% else -%>"
        out "<%= zazen(#{text}#{limit}, :node=>#{node(Node)}) %>"
        out "<% end -%>#{post}"
      else
        out "#{pre}#{post}"
      end
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
      @html_tag ||= 'div'
      if @html_tag_params[:id]
        # add a sub-div
        pre  = "<div id='v_summary#{erb_node_id}'>"
        post = "</div>"
      else
        pre = post = ''
        @html_tag_params[:id] = "v_summary#{erb_node_id}"
      end
      
      add_html_class('zazen')
      
      unless @params[:or]
        text = @params[:text] ? @params[:text].inspect : node_attribute('v_summary')
        out "#{pre}<%= zazen(#{text}#{limit}, :node=>#{node(Node)}) %>#{post}"
      else
        limit ||= ', :limit => 2'
        first_name = 'v_summary'
        first  = node_attribute(first_name)
        
        second_name = @params[:or].gsub(/[^a-z_]/,'') # FIXME: ist this still needed ? (ERB injection)
        second = node_attribute(second_name)
        out "#{pre}<% if #{first} != '' %>"
        out "<%= zazen(#{first}, :node=>#{node(Node)}) %>"
        out "<% else %>"
        out "<%= zazen(#{second}#{limit}, :node=>#{node(Node)}) %>"
        out "<% end %>#{post}"
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
    
    def r_comments_to_publish
      open_context("visitor.comments_to_publish", :node_class => [Comment])
    end

    def r_to_publish
      open_context("visitor.to_publish", :node_class => [Version])
    end
    
    def r_proposed
      open_context("visitor.proposed", :node_class => [Version])
    end

    def r_redactions
      open_context("visitor.redactions", :node_class => [Version])
    end
    
    def r_edit
      
      if @context[:dom_prefix]
        # ajax
        if @context[:in_form]
          # cancel button
          @context[:form_cancel] || ''
        else
          # edit button
          
          # TODO: show 'reply' instead of 'edit' in comments if visitor != author
          out link_to_update(self, :default_text => _('edit'), :url => "\#{edit_#{base_class.to_s.underscore}_path(#{node_id})}", :html_params => get_html_params(@params, :link), :method => :get, :cond => "#{node}.can_write?", :else => :void)
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
    
    
    # <r:select name='klass' root_class='...'/>
    # <r:select name='parent_id' values='projects in site'/>
    # TODO: optimization (avoid loading full AR to only use [id, name])
    def r_select
      html_attributes, attribute = get_input_params()
      return parser_error("missing name") unless attribute
      if value = @params[:selected]
        # FIXME: DRY with html_attributes
        value = value.gsub(/\[([^\]]+)\]/) do
          node_attr = $1
          res = node_attribute(node_attr)
          "\#{#{res}}"
        end
        selected = value.inspect
      elsif @context[:in_filter]
        selected = "params[#{attribute.to_sym.inspect}].to_s"
      else
        selected = "#{node_attribute(attribute)}.to_s"
      end
      html_id = html_attributes[:id] ? " id='#{html_attributes[:id]}'" : ''
      if @context[:in_filter]
        select_tag = "<select#{html_id} name='#{attribute}'>"
      else
        select_tag = "<select#{html_id} name='#{base_class.to_s.underscore}[#{attribute}]'>"
      end
      
      if klass = @params[:root_class]
        class_opts = {}
        class_opts[:without]   = @params[:without]  if @params[:without]
        # do not use 'selected' if the node is not new
        "#{select_tag}<%= options_for_select(Node.classes_for_form(:class => #{klass.inspect}#{params_to_erb(class_opts)}), (#{node}.new_record? ? #{selected} : #{node}.klass)) %></select>"
      elsif @params[:type] == 'time_zone'
        # <r:select name='d_tz' type='time_zone'/>
        "#{select_tag}<%= options_for_select(TZInfo::Timezone.all_identifiers, #{selected}) %></select>"
      elsif options_list = get_options_for_select
        "#{select_tag}<%= options_for_select(#{options_list}, #{selected}) %></select>"
      else
        parser_error("missing 'nodes', 'root_class' or 'values'")
      end
    end
    
    
    def r_input
      html_attributes, attribute = get_input_params()
      case @params[:type]
      when 'select' # FIXME: why is this only for classes ?
        out parser_error("please use [select] here")
        r_select
      when 'date_box', 'date'
        return parser_error("date_box without name") unless attribute
        input_id = @context[:dom_prefix] ? ", :id=>\"#{dom_id}_#{attribute}\"" : ''
        "<%= date_box '#{base_class.to_s.underscore}', #{attribute.inspect}, :size=>15#{@context[:in_add] ? ", :value=>''" : ''}#{input_id} %>"
      when 'id'
        return parser_error("select id without name") unless attribute
        name = "#{attribute}_id" unless attribute[-3..-1] == '_id'
        input_id = @context[:erb_dom_id] ? ", :input_id =>\"#{erb_dom_id}_#{attribute}\"" : ''
        "<%= select_id('#{base_class.to_s.underscore}', #{attribute.inspect}#{input_id}) %>"
      when 'time_zone'
        out parser_error("please use [select] here")
        r_select
      when 'submit'
        @html_tag = 'input'
        @html_tag_params[:type] = @params[:type]
        @html_tag_params[:text] = @params[:text] if @params[:text]
        @html_tag_params.merge!(html_attributes)
        render_html_tag(nil)
      else
        # 'text', 'hidden', ...
        @html_tag = 'input'
        @html_tag_params[:type] = @params[:type] || 'text'
        @html_tag_params.merge!(html_attributes)
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
      hidden_fields = {}
      set_fields = []
      id_hash    = {:class => @html_tag_params[:class] || @params[:class] || 'form'}
      var_name   = base_class.to_s.underscore
      (descendants('input') + descendants('select')).each do |tag|
        set_fields << "#{var_name}[#{tag.params[:name]}]"
      end
      
      if @context[:dom_prefix] || @params[:update]
        # ajax
        if @context[:in_add]
          # inline form used to create new elements: set values to '' and 'parent_id' from context
          id_hash[:id] = "#{erb_dom_id}_form"
          id_hash[:style] = "display:none;"
          
          cancel =  "<p class='btn_x'><a href='#' onclick='[\"#{erb_dom_id}_add\", \"#{erb_dom_id}_form\"].each(Element.toggle);return false;'>#{_('btn_x')}</a></p>\n"
          form  =  "<%= form_remote_tag(:url => #{base_class.to_s.underscore.pluralize}_path, :html => {:id => \"#{dom_id}_form_t\"}) %>\n"
        else
          # saved form
          
          id_hash[:id] = erb_dom_id
          
          cancel = !@context[:dom_prefix] ? "" : <<-END_TXT
<% if #{node}.new_record? -%>
  <p class='btn_x'><a href='#' onclick='[\"<%= params[:dom_id] %>_add\", \"<%= params[:dom_id] %>_form\"].each(Element.toggle);return false;'>#{_('btn_x')}</a></p>
<% else -%>
  <p class='btn_x'><%= link_to_remote(#{_('btn_x').inspect}, :url => #{base_class.to_s.underscore}_path(#{node_id}) + \"/zafu?t_url=#{CGI.escape(template_url)}&dom_id=\#{params[:dom_id]}#{@context[:need_link_id] ? "&link_id=\#{#{node}.link_id}" : ''}\", :method => :get) %></p>
<% end -%>
END_TXT
          form =<<-END_TXT
<% if #{node}.new_record? -%>
<%= form_remote_tag(:url => #{base_class.to_s.underscore.pluralize}_path, :html => {:id => \"\#{params[:dom_id]}_form_t\"}) %>
<% else -%>
<%= form_remote_tag(:url => #{base_class.to_s.underscore}_path(#{node_id}), :method => :put, :html => {:id => \"#{dom_id}_form_t\"}) %>
<% end -%>
END_TXT
        end
        
        if @context[:make_form] ? (descendants('show') != []) : (descendants('input') != [])
          # has submit
        else
          append_submit = "<input type='submit'/>"
        end
        
        hidden_fields['link_id'] = "<%= #{node}.link_id %>" if @context[:need_link_id]
        
        if @params[:update] || (@context[:add] && @context[:add].params[:update])
          upd = @params[:update] || @context[:add].params[:update]
          if target = find_target(upd)
            hidden_fields['u_url']   = target.template_url
            hidden_fields['udom_id'] = target.erb_dom_id
            hidden_fields['u_id']    = "<%= #{@context[:parent_node]}.zip %>" if @context[:in_add]
            hidden_fields['s']       = start_node_s_param(:value)
          end
        elsif (block = ancestor('block')) && node_kind_of?(DataEntry)
          # updates template url
          hidden_fields['u_url']   = block.template_url
          hidden_fields['udom_id'] = block.erb_dom_id
        end
        
        hidden_fields['t_url'] = template_url
        if t_id = @params[:t_id]
          hidden_fields['t_id']  = parse_attributes_in_value(t_id)
        end
        
        erb_dom_id = @context[:saved_template] ? '<%= params[:dom_id] %>' : self.erb_dom_id

        hidden_fields['dom_id'] = erb_dom_id
        
        if node_kind_of?(Node)
          hidden_fields['node[parent_id]'] = "<%= #{@context[:in_add] ? "#{@context[:parent_node]}.zip" : "#{node}.parent_zip"} %>"
        elsif node_kind_of?(Comment)
          # FIXME: the "... || '@node'" is a hack and I don't understand why it's needed...
          hidden_fields['node_id'] = "<%= #{@context[:parent_node] || '@node'}.zip %>"
        elsif node_kind_of?(DataEntry)
          hidden_fields["data_entry[#{@context[:data_root]}_id]"] = "<%= #{@context[:in_add] ? @context[:parent_node] : "#{node}.#{@context[:data_root]}"}.zip %>"
        end
        
        if add_block = @context[:add]
          params = add_block.params
          [:after, :before, :top, :bottom].each do |sym|
            if params[sym]
              hidden_fields['position'] = sym.to_s
              if params[sym] == 'self'
                if sym == :before
                  hidden_fields['reference'] = "#{erb_dom_id}_add"
                else
                  hidden_fields['reference'] = "#{erb_dom_id}_form"
                end
              else  
                hidden_fields['reference'] = params[sym]
              end
              break
            end
          end
          if params[:done] == 'focus'
            if params[:focus]
              hidden_fields['done'] = "'$(\"#{erb_dom_id}_#{@params[:focus]}\").focus();'"
            else
              hidden_fields['done'] = "'$(\"#{erb_dom_id}_form_t\").focusFirstElement();'"
            end
          elsif params[:done]
            hidden_fields['done'] = CGI.escape(params[:done]) # .gsub("NODE_ID", @node.zip).gsub("PARENT_ID", @node.parent_zip)
          end
        else
          # ajax form, not in 'add'
          hidden_fields['done'] = CGI.escape(@params[:done]) if @params[:done]
        end
      else
        # no ajax
        # FIXME
        cancel = "" # link to normal node ?
        form = "<form method='post' action='/nodes/#{erb_node_id}'><div style='margin:0;padding:0'><input name='_method' type='hidden' value='put' /></div>"
      end
      
      if node_kind_of?(Node) && (@params[:klass] || @context[:klass])
        hidden_fields['node[klass]']    = @params[:klass] || @context[:klass]
      end
      
      if node_kind_of?(Node) && @params[:mode]
        hidden_fields['mode'] = @params[:mode]
      end
      
      hidden_fields['node[v_status]'] = Zena::Status[:pub] if @context[:publish_after_save] || (@params[:publish] == 'true')
      
      form << "<div class='hidden'>"
      hidden_fields.each do |k,v|
        next if set_fields.include?(k)
        v = "'#{v}'" unless v.kind_of?(String) && ['"', "'"].include?(v[0..0])
        form << "<input type='hidden' name='#{k}' value=#{v}/>\n"
      end
      form << "</div>"
      
      form << "<%= error_messages_for(#{node}) %>"
      
      if !descendant('cancel') && !descendant('edit')
        if !descendant('form_tag')
          # add a descendant before blocks.
          blocks_bak = @blocks
          @blocks = @blocks.dup
          @blocks = [make(:void, :method=>'void', :text=>cancel)] + blocks_bak
        else
          form   = cancel + form
          cancel = ''
        end
      end
      
      if append_submit
        # add a descendant after blocks.
        unless blocks_bak
          blocks_bak = @blocks
          @blocks = @blocks.dup
        end
        make(:void, :method=>'void', :text=>append_submit)
      end
      
      if descendant('form_tag')
        res = expand_with(:form_tag => form, :in_form => true, :form_cancel => cancel, :erb_dom_id => erb_dom_id, :dom_id => dom_id)
      else
        res = form + expand_with(:in_form => true, :form_cancel => cancel, :erb_dom_id => erb_dom_id, :dom_id => dom_id) + '</form>'
      end
      
      @blocks = blocks_bak if blocks_bak
      
      @html_tag_done = false
      @html_tag_params.merge!(id_hash)
      out render_html_tag(res)
    end
    
    # <r:checkbox role='collaborator_for' values='projects' in='site'/>"
    # TODO: implement checkbox in the same spirit as 'r_select'
    def r_checkbox
      return parser_error("missing 'nodes'") unless values = @params[:values] || @params[:nodes]
      return parser_error("missing 'role'")   unless   role = (@params[:role] || @params[:name])
      attribute = @params[:attr] || 'name'
      if role =~ /(.*)_ids?\Z/
        role = $1
      end
      meth = role.singularize

      if values =~ /^\d+\s*($|,)/
        # ids
        # TODO generate the full query instead of using secure.
        values = values.split(',').map{|v| v.to_i}
        list_finder = "(secure(Node) { Node.find(:all, :conditions => 'zip IN (#{values.join(',')})') })"
      else
        # relation
        list_finder, klass = build_finder_for(:all, values)
        return unless list_finder
        return parser_error("invalid class (#{klass})") unless klass.ancestors.include?(Node)
      end
      out "<% if (#{list_var} = #{list_finder}) && (#{list_var}_relation = #{node}.relation_proxy(#{role.inspect})) -%>"
      out "<% if #{list_var}_relation.unique? -%>"
    
      out "<% #{list_var}_id = #{list_var}_relation.other_id -%>"
      out "<div class='input_radio'><% #{list_var}.each do |#{var}| -%>"
      out "<span><input type='radio' name='node[#{meth}_id]' value='#{erb_node_id(var)}'<%= #{list_var}_id == #{var}[:id] ? \" checked='checked'\" : '' %>/> <%= #{node_attribute(attribute, :node=>var)} %></span> "
      out "<% end -%></div>"
      out "<input type='radio' name='node[#{meth}_id]' value=''/> #{_('none')}"

      out "<% else -%>"

      out "<% #{list_var}_ids = #{list_var}_relation.other_ids -%>"
      out "<div class='input_checkbox'><% #{list_var}.each do |#{var}| -%>"
      out "<span><input type='checkbox' name='node[#{meth}_ids][]' value='#{erb_node_id(var)}'<%= #{list_var}_ids.include?(#{var}[:id]) ? \" checked='checked'\" : '' %>/> <%= #{node_attribute(attribute, :node=>var)} %></span> "
      out "<% end -%></div>"
      out "<input type='hidden' name='node[#{meth}_ids][]' value=''/>"

      out "<% end -%><% end -%>"
    end    
    
    alias r_radio r_checkbox
    
    # TODO: test
    def r_add
      return parser_error("should not be called from within 'each'") if parent.method == 'each'
      return '' if @context[:make_form]
      
      # why is node = @node (which we need) but we are supposed to have Comments ?
      # FIXME: during rewrite, replace 'node' by 'node(klass = node_class)' so the ugly lines below would be
      # if node_kind_of?(Comment)
      #   out "<% if #{node(Node)}.can_comment? -%>"
      # Refs #198.
      if node_kind_of?(Comment)
        out "<% if #{node}.can_comment? -%>"
      else
        out "<% if #{node}.can_write? -%>"
      end
      
      unless descendant('add_btn')
        # add a descendant between self and blocks.
        blocks = @blocks.dup
        @blocks = []
        add_btn = make(:void, :method=>'add_btn', :params=>@params.dup, :text=>'')
        add_btn.blocks = blocks
        remove_instance_variable(:@all_descendants)
      end
      
      if @context[:form] && @context[:dom_prefix]
        # ajax add
        
        @html_tag_params.merge!(:id => "#{erb_dom_id}_add")
        @html_tag_params[:class] ||= 'btn_add'
        if @params[:focus]
          focus = "$(\"#{erb_dom_id}_#{@params[:focus]}\").focus();"
        else
          focus = "$(\"#{erb_dom_id}_form_t\").focusFirstElement();"
        end
        
        out render_html_tag("#{expand_with(:onclick=>"[\"#{erb_dom_id}_add\", \"#{erb_dom_id}_form\"].each(Element.toggle);#{focus}return false;")}")
        
        if node_kind_of?(Node)
          # FIXME: BUG if we set <r:form klass='Post'/> the user cannot select class with menu...
          klass = @context[:klass] || 'Node'
          # FIXME: inspect '@context[:form]' to see if it contains v_klass ?
          out "<% if #{var}_new = secure(Node) { Node.new_from_class(#{klass.inspect}) } -%>"
        else
          out "<% if #{var}_new = #{node_class}.new -%>"
        end
        
        if @context[:form].method == 'form'
          out expand_block(@context[:form], :in_add => true, :no_ignore => ['form'], :add=>self, :node => "#{var}_new", :parent_node => node, :klass => klass, :publish_after_save => (@params[:publish] == 'true'))
        else
          # build form from 'each'
          out expand_block(@context[:form], :in_add => true, :no_ignore => ['form'], :add=>self, :make_form => true, :node => "#{var}_new", :parent_node => node, :klass => klass, :publish_after_save => (@params[:publish] == 'true'))
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
        text = node_class == Comment ? _("btn_add_comment") : _("btn_add")
      end
      
      out "<a href='#' onclick='#{@context[:onclick]}'>#{text}</a>"
    end
    
    # Show html to add open a popup window to add a document.
    # TODO: inline ajax for upload ?
    def r_add_document
      return parser_error("only works with nodes (not with #{node_class})") unless node_kind_of?(Node)
      @html_tag_params[:class] ||= 'btn_add'
      res = "<a href='/documents/new?parent_id=#{erb_node_id}' onclick='uploader=window.open(\"/documents/new?parent_id=#{erb_node_id}\", \"upload\", \"width=400,height=300\");return false;'>#{_('btn_add_doc')}</a>"
      "<% if #{node}.can_write? -%>#{render_html_tag(res)}<% end -%>"
    end
    
    #if RAILS_ENV == 'test'
    #  def r_test
    #    inspect
    #  end
    #end
    
    def r_drop
      if parent.method == 'each' && @method == parent.single_child_method
        parent.add_html_class('drop')
      else
        @html_tag_params[:class] ||= 'drop'
      end
      r_block
    end
    
    def drop_javascript
      hover  = @params[:hover]
      change = @params[:change]
    
      if role = @params[:set] || @params[:add]
        query_params = ["node[#{role}_id]=[id]"]
      else
        query_params = []
        # set='icon_for=[id], v_status='50', v_title='[v_title]'
        @params.each do |k, v|
          next if [:hover, :change, :done].include?(k)
          value, static = parse_attributes_in_value(v, :erb => false, :skip_node_attributes => true)
          key = change == 'params' ? "params[#{k}]" : "node[#{k}]"
          query_params << "#{key}=#{CGI.escape(value)}"
        end
        return parser_error("missing parameters to set values") if query_params == []
      end
    
      query_params << "change=#{change}" if change == 'receiver'
      query_params << "t_url=#{CGI.escape(template_url)}"
      query_params << "dom_id=#{erb_dom_id}"
      query_params << start_node_s_param(:erb)
      query_params << "done=#{CGI.escape(@params[:done])}" if @params[:done]
    
      "<script type='text/javascript'>
      //<![CDATA[
      Droppables.add('#{erb_dom_id}', {hoverclass:'#{hover || 'drop_hover'}', onDrop:function(element){new Ajax.Request('/nodes/#{erb_node_id}/drop?#{query_params.join('&')}', {asynchronous:true, evalScripts:true, method:'put', parameters:'drop=' + encodeURIComponent(element.id)})}})
      //]]>
      </script>"
    end
    
    def r_draggable
      new_dom_scope
      @html_tag ||= 'div'
      case @params[:revert]
      when 'move'
        revert_effect = 'Element.move'
      when 'remove'
        revert_effect = 'Element.remove'
      else
        revert_effect = 'Element.move'
      end
      
      res, drag_handle = set_drag_handle_and_id(expand_with, @params, :id => erb_dom_id)
      
      out render_html_tag(res)
      
      if drag_handle
        out "<script type='text/javascript'>\n//<![CDATA[\n
          new Draggable('#{erb_dom_id}', {ghosting:true, revert:true, revertEffect:#{revert_effect}, handle:$('#{erb_dom_id}').select('.#{drag_handle}')[0]});\n//]]>\n</script>"
      else
        out "<script type='text/javascript'>\n//<![CDATA[\nZena.draggable('#{erb_dom_id}',0,true,true,#{revert_effect})\n//]]>\n</script>"
      end
    end
 
    def r_unlink
      return "" if @context[:make_form]
      opts = {}
      
      if upd = @params[:update]
        if upd == '_page'
          target = nil
        elsif target = find_target(upd)
          # ok
        else
          return
        end
      elsif target = ancestor('block')
        # ok
      else
        target = self
      end
      
      if node_kind_of?(Node)
        opts[:cond] = "#{node}.can_write? && #{node}.link_id"
        opts[:url] = "/nodes/\#{#{node_id}}/links/\#{#{node}.link_id}"
      elsif node_kind_of?(Link)
        opts[:url] = "/nodes/\#{#{node}.this_zip}/links/\#{#{node}.zip}"
      end
      
      opts[:method]       = :delete
      opts[:default_text] = _('btn_tiny_del')
      opts[:html_params]  = get_html_params({:class => 'unlink'}.merge(@params), :link)
      
      out link_to_update(target, opts)
      
     #tag_to_remote
     #"<%= tag_to_remote({:url => node_path(#{node_id}) + \"#{opts[:method] != :put ? '/zafu' : ''}?#{action.join('&')}\", :method => #{opts[:method].inspect}}) %>"
     #  out "<a class='#{@params[:class] || 'unlink'}' href='/nodes/#{erb_node_id}/links/<%= #{node}.link_id %>?#{action}' onclick=\"new Ajax.Request('/nodes/#{erb_node_id}/links/<%= #{node}.link_id %>?#{action}', {asynchronous:true, evalScripts:true, method:'delete'}); return false;\">"
     #  if !@blocks.empty?
     #    inner = expand_with
     #  else
     #    inner = _('btn_tiny_del')
     #  end
     #  out "#{inner}</a><% else -%>#{inner}<% end -%>"
     #elsif node_kind_of?(DataEntry)
     #  text = get_text_for_erb
     #  if text.blank?
     #    text = _('btn_tiny_del')
     #  end
     #  out "<%= link_to_remote(#{text.inspect}, {:url => \"/data_entries/\#{#{node}[:id]}?dom_id=#{dom_id}#{upd_url}\", :method => :delete}, :class=>#{(@params[:class] || 'unlink').inspect}) %>"
     #end
    end
    
    # Group elements in a list. Use :order to specify order.
    def r_group
      return parser_error("cannot be used outside of a list") unless list_var = @context[:list]
      return parser_error("missing 'by' clause") unless key = @params[:by]

      sort_key = @params[:sort] || 'name'
      if node_kind_of?(DataEntry) && DataEntry::NodeLinkSymbols.include?(key.to_sym)
        key = "#{key}_id"
        sort_block = "{|e| (e.#{key} || {})[#{sort_key.to_sym.inspect}]}"
        group_array = "group_array(#{list_var}) {|e| e.#{key}}"
      elsif node_kind_of?(Node)
        if ['project', 'parent', 'section'].include?(key)
          sort_block  = "{|e| (e.#{key} || {})[#{sort_key.to_sym.inspect}]}"
          group_array = "group_array(#{list_var}) {|e| e.#{key}_id}"
        end
      end
      
      group_array ||= "group_array(#{list_var}) {|e| #{node_attribute(key, :node => 'e')}}"
      
      if sort_block
        out "<% grp_#{list_var} = sort_array(#{group_array}) #{sort_block} -%>"
      else
        out "<% grp_#{list_var} = #{group_array} -%>"
      end
      
      if descendant('each_group')
        out expand_with(:group => "grp_#{list_var}")
      else
        @context[:group] = "grp_#{list_var}"
        r_each_group
      end
    end

    
    # Compute statistics on elements in the current list context.
    def r_stat
      return parser_error("must be used inside a list context") unless list
      find = @params[:find] || @params[:date] || 'count'
      key  = @params[:of]   || @params[:from] || 'value'
      case find
      when 'sum'
        value = "#{list}.flatten.inject(0) {|#{var}_sum,#{var}| #{var}_sum + #{node_attribute(key, :node => var)}.to_f}"
      when 'min'
        value = "#{node_attribute(key, :node => "min_array(#{list}) {|e| #{node_attribute(key, :node => 'e')}}")}"
      when 'max'
        value = "#{node_attribute(key, :node => "max_array(#{list}) {|e| #{node_attribute(key, :node => 'e')}}")}"
      when 'count'
        return "<%= #{list}.size %>"
      end
      if @params[:date]
        # FIXME: DRY (r_show)
        if @params[:tformat]
          format = _(@params[:tformat])
        elsif @params[:format]
          format = @params[:format]
        else
          format = "%Y-%m-%d"
        end
        "<%= #{list}==[] ? '' : format_date(#{value}, #{format.inspect}) %>"
      elsif format = @params[:format]
        
        if @params[:zero] == 'hide'
          "<%= #{list}==[] ? '' : sprintf_unless_zero(#{@params[:format].inspect}, #{value}) %>"
        else
          "<%= #{list}==[] ? '' : sprintf(#{@params[:format].inspect}, #{value}) %>"
        end
      else
        "<%= #{list}==[] ? '' : #{value} %>"
      end
    end

    def r_each_group
      return parser_error("must be used inside a group context") unless group = @context[:group]
      if join = @params[:join]
        join = join.gsub(/&lt;([^%])/, '<\1').gsub(/([^%])&gt;/, '\1>')
        out "<% #{group}.each_index do |#{list_var}_index| -%>"
        out "<%= #{list_var}=#{group}[#{list_var}_index]; #{var} = #{list_var}[0]; #{list_var}_index > 0 ? #{join.inspect} : '' %>"
      else
        out "<% #{group}.each do |#{list_var}|; #{var} = #{list_var}[0]; -%>"
      end
      out render_html_tag(expand_with(:group => nil, :list => list_var, :node => var, :scope_node => var))
      out "<% end -%>"
    end
    
    def r_each
      is_draggable = @params[:draggable] == 'true' || @params[:drag_handle]
      
      if descendant('edit') || descendant('unlink') || descendant('swap') || ['block', 'drop'].include?(single_child_method) || is_draggable
        id_hash = {:id => erb_dom_id}
      else
        id_hash = nil
      end
      
      
      if @context[:make_form]
        # use the elements inside 'each' loop to produce the edit form
        r_form
      elsif @context[:list]
        # normal rendering: not the start of a saved template
        if is_draggable || descendant('unlink')
          out "<% #{var}_dom_ids = [] -%>"
        end
        
        @params[:alt_class] ||= @html_tag_params.delete(:alt_class)
        # FIXME: add alt_reverse='true' to start counting from bottom (if order last on top...)
        if @params[:alt_class] || @params[:join]
          join = @params[:join] || ''
          join = join.gsub(/&lt;([^%])/, '<\1').gsub(/([^%])&gt;/, '\1>')
          out "<% #{var}_max_index = #{list}.size - 1 -%>" if @params[:alt_reverse]
          out "<% #{list}.each_with_index do |#{var},#{var}_index| -%>"
          out "<%= #{var}_index > 0 ? #{join.inspect} : '' %>"
          
          if alt_class = @params[:alt_class]
            alt_test = @params[:alt_reverse] == 'true' ? "(#{var}_max_index - #{var}_index) % 2 != 0" : "#{var}_index % 2 != 0"
            if html_class = @html_tag_params.delete(:class)
              html_append = " class='#{html_class}<%= #{alt_test} ? #{(' ' + alt_class).inspect} : '' %>'"
            else
              html_append = "<%= #{alt_test} ? ' class=#{alt_class.inspect}' : '' %>"
            end
          else
            html_append = nil
          end
        else
          out "<% #{list}.each do |#{var}| -%>"
          html_append = nil
        end
        
        if is_draggable
          out "<% #{var}_dom_ids << \"#{dom_id}\" -%>"
        end
        
        out r_anchor(var) if @anchor_param # insert anchor inside the each loop
        @params[:anchor] = @anchor_param   # set back in case we double render
        @anchor_param = nil
        
        res, drag_handle = set_drag_handle_and_id(expand_with(:node => var, :scope_node => var), @params, id_hash)
        
        out render_html_tag(res, html_append)
        
        out "<% end -%>"
        
        if is_draggable
          if drag_handle
            out "<script type='text/javascript'>\n//<![CDATA[\n<%= #{var}_dom_ids.inspect %>.each(function(dom_id, index) {
                new Draggable(dom_id, {ghosting:true, revert:true, handle:$(dom_id).select('.#{drag_handle}')[0]});
            });\n//]]>\n</script>"
          else
            out "<script type='text/javascript'>\n//<![CDATA[\n<%= #{var}_dom_ids.inspect %>.each(Zena.draggable)\n//]]>\n</script>"
          end
        end
        
      elsif @context[:saved_template]
        # render to start a saved template
        res, drag_handle = set_drag_handle_and_id(expand_with(:scope_node => node), @params, id_hash)
        
        out render_html_tag(res)
        
        if is_draggable
          if drag_handle
            out "<script type='text/javascript'>\n//<![CDATA[\nnew Draggable('#{erb_dom_id}', {ghosting:true, revert:true, handle:$('#{erb_dom_id}').select('.#{drag_handle}')[0]});\n//]]>\n</script>"
          else
            out "<script type='text/javascript'>\n//<![CDATA[\nZena.draggable('#{erb_dom_id}')\n//]]>\n</script>"
          end
        end
      else
        # TODO: make a single list ?
        @context[:list] = "[#{node}]"
        r_each
      end
    end
    
    def r_case
      out "<% if false -%>"
      out expand_with(:in_if=>true, :only=>['when', 'else'], :html_tag => @html_tag, :html_tag_params => @html_tag_params)
      @html_tag_done = true
      out "<% end -%>"
    end
    
    # TODO: test
    def r_if
      cond = get_test_condition
      return parser_error("condition error") unless cond
      
      if cond == 'true'
        return expand_with(:in_if => false)
      elsif cond == 'false'
        if descendant('else') || descendant('elsif')
          return expand_with(:in_if=>true, :only=>['elsif', 'else'])
        else
          @html_tag_done = true
          return ''
        end
      end
      
      out "<% if #{cond} -%>"
      out render_html_tag(expand_with(:in_if=>false))
      out expand_with(:in_if=>true, :only=>['elsif', 'else'], :html_tag => @html_tag, :html_tag_params => @html_tag_params)
      out "<% end -%>"
    end
    
    def r_else
      if @context[:in_if]
        @html_tag = @context[:html_tag]
        @html_tag_params = @context[:html_tag_params] || {}
        out "<% elsif true -%>"
        if @params[:text]
          out render_html_tag(@params[:text])
        else
          out render_html_tag(expand_with(:in_if=>false, :only => nil)) # do not propagate :only from ancestor 'if' clause
        end
      else
        ""
      end
    end
    
    def r_elsif
      return '' unless @context[:in_if]
      @html_tag = @context[:html_tag]
      @html_tag_params = @context[:html_tag_params] || {}
      cond = get_test_condition
      return parser_error("condition error") unless cond
      out "<% elsif #{cond} -%>"
      out render_html_tag(expand_with(:in_if=>false, :only => nil)) # do not propagate :only from ancestor 'if' clause
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
    
    def r_date
      select = @params[:select]
      case select
      when 'main'
        expand_with(:date=>"main_date")
      when 'now'
        expand_with(:date=>"Time.now")
      else
        if select =~ /^\d{4}-\d{1,2}-\d{1,2}$/
          begin
            d = Date.parse(select)
            expand_with(:date=>select.inspect)
          rescue
            parser_error("invalid date '#{select}' should be 'YYYY-MM-DD'")
          end
        elsif date = find_stored(Date, select)
          if date[0..0] == '"'
            begin
              d = Date.parse(date[1..-2])
              expand_with(:date=>date)
            rescue
              parser_error("invalid date #{select} (#{date}) should be 'YYYY-MM-DD'")
            end
          else
            expand_with(:date=>select)
          end
        elsif select =~ /\[(.*)\]/
          date, static = parse_attributes_in_value(select, :erb => false)
          expand_with(:date => "\"#{date}\"")
        else
          parser_error("bad parameter '#{select}'")
        end
      end
    end
    
    def r_javascripts
      if @params[:list].nil?
        list = %w{ prototype effects tablekit zena }
      elsif @params[:list] == 'all'
        list = %w{ prototype effects dragdrop tablekit zena }
      else
        list = @params[:list].split(',').map{|e| e.strip}
      end
      helper.javascript_include_tag(*list)
    end
    
    def r_stylesheets
      if @params[:list] == 'all' || @params[:list].nil?
        list = %w{ zena code }
      else
        list = @params[:list].split(',').map{|e| e.strip}
      end
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
      if logo = @params[:logo]
        # FIXME
        case logo
        when 'tiny'
        else
        end
      else
        text = case @params[:type]
        when 'riding'
          _("riding zena")
        when 'peace'
          _("in peace with zena")
        when 'garden'
          _("a zen garden")
        else
          _("made with zena")
        end
        "<a class='zena' href='http://zenadmin.org' title='zena <%= Zena::VERSION::STRING %> r<%= Zena::VERSION::REV %>'>#{text}</a>"
      end
    end
    
    def r_design
      if @params[:by]
        by = "<a href='#{@params[:href]}'>#{@params[:by]}</a>"
      else
        by = expand_with(:trans => true)
      end
      unless skin = @params[:skin]
        skin = helper.instance_variable_get(:@controller).instance_variable_get(:@skin_name)
      end
      skin = "<i>#{skin}</i>" unless skin.blank?
      _("%{skin}, design by %{name}") % {:name => by, :skin => skin}
    end
    
    # creates a link. Options are:
    # :href (node, parent, project, root)
    # :tattr (translated attribute used as text link)
    # :attr (attribute used as text link)
    # <r:link href='node'><r:trans attr='lang'/></r:link>
    # <r:link href='node' tattr='lang'/>
    # <r:link update='dom_id'/>
    # <r:link page='next'/> <r:link page='previous'/> <r:link page='list'/>
    def r_link
      if @params[:page]
        pagination_links
      else
        make_link
      end
    end
    
    def make_link(options = {})
      query_params = options[:query_params] || {}
      default_text = options[:default_text]
      params = @params.dup
      
      opts = {}
      if upd = params.delete(:update)
        return unless remote_target = find_target(upd)
      end
      
      if href = params.delete(:href)
        if lnode = find_stored(Node, href)
          # using stored node
        else
          lnode, klass = build_finder_for(:first, href, {})
          return unless lnode
          return parser_error("invalid class (#{klass})") unless klass.ancestors.include?(Node)
        end
      else
        # obj
        if node_class == Version
          lnode = "#{node}.node"
          opts[:lang] = "#{node}.lang"
        elsif node_kind_of?(Node)
          lnode = node
        else
          lnode = @context[:previous_node]
        end
      end
      
      if fmt = params.delete(:format)
        if fmt == 'data'
          opts[:format] = "#{node}.c_ext"
        else
          opts[:format] = fmt.inspect
        end
      end

      if mode = params.delete(:mode)
        opts[:mode] = mode.inspect
      end

      if sharp = params.delete(:sharp)
        opts[:sharp] = sharp.inspect
      end

      if sharp_in = params.delete(:in)
        finder, klass = build_finder_for(:first, sharp_in, {})
        return unless finder
        return parser_error("invalid class (#{klass})") unless klass.ancestors.include?(Node)
        opts[:sharp_in] = finder
      end

      if @html_tag && @html_tag != 'a'
        # FIXME: can we remove this ?
        # html attributes do not belong to anchor
        pre_space = ''
        html_params = {}
      else
        html_params = get_html_params(params.merge(@html_tag_params), :link)
        pre_space = @space_before || ''
        @html_tag_done = true
      end
      
      (params.keys - [:style, :class, :id, :rel, :name, :anchor, :attr, :tattr, :trans, :text, :page]).each do |k|
        next if k.to_s =~ /if_|set_/
        query_params[k] = params[k]
      end
      
      # TODO: merge these two query_params cleanup things into something cleaner.
      if remote_target
        # ajax
        query_params_list = []
        query_params.each do |k,v|
          if k == :date
            if v == 'current_date'
              str = "\#{#{current_date}}"
            elsif v =~ /\A\d/
              str = CGI.escape(v.gsub('"',''))
            elsif v =~ /\[/
              attribute, static = parse_attributes_in_value(v.gsub('"',''), :erb => false)
              str = static ? CGI.escape(attribute) : "\#{CGI.escape(\"#{attribute}\")}"
            else
              str = "\#{CGI.escape(#{node_attribute(v)})}"
            end
          else  
            attribute, static = parse_attributes_in_value(v.gsub('"',''), :erb => false)
            str = static ? CGI.escape(attribute) : "\#{CGI.escape(\"#{attribute}\")}"
          end
          query_params_list << "#{k.to_s.gsub('"','')}=#{str}"
        end
        pre_space + link_to_update(remote_target, :node_id => "#{lnode}.zip", :query_params => query_params_list, :default_text => default_text, :html_params => html_params)
      else
        # direct link
        query_params.each do |k,v|
          if k == :date
            if v == 'current_date'
              query_params[k] = current_date
            elsif v =~ /\A\d/
              query_params[k] = v.inspect
            elsif v =~ /\[/
              attribute, static = parse_attributes_in_value(v.gsub('"',''), :erb => false)
              query_params[k] = "\"#{attribute}\""
            else
              query_params[k] = node_attribute(v)
            end
          else  
            attribute, static = parse_attributes_in_value(v.gsub('"',''), :erb => false)
            query_params[k] = "\"#{attribute}\""
          end
        end
        
        query_params.merge!(opts)
        
        opts_str = ''
        query_params.keys.sort {|a,b| a.to_s <=> b.to_s }.each do |k|
          opts_str << ",:#{k.to_s.gsub(/[^a-z_A-Z_]/,'')}=>#{query_params[k]}"
        end
        
        opts_str += ", :host => #{@context["exp_host"]}" if @context["exp_host"]
        
        pre_space + "<a#{params_to_html(html_params)} href='<%= zen_path(#{lnode}#{opts_str}) %>'>#{text_for_link(default_text)}</a>"
      end
    end
    
    # <r:link page='next'/> <r:link page='previous'/> <r:link page='list'/>
    def pagination_links
      return parser_error("not in pagination scope") unless pagination_key = @context[:paginate]
      case @params[:page]
      when 'previous'
        out "<% if set_#{pagination_key}_previous = (set_#{pagination_key} > 1 ? set_#{pagination_key} - 1 : nil) -%>"
        @context[:vars] ||= []
        @context[:vars] << "#{pagination_key}_previous"
        out make_link(:default_text => "<%= set_#{pagination_key}_previous %>", :query_params => {pagination_key => "[#{pagination_key}_previous]"})
        if descendant('else')
          out expand_with(:in_if => true, :only => ['else', 'elsif'])
        end
        out "<% end -%>"
      when 'next'
        out "<% if set_#{pagination_key}_next = (set_#{pagination_key}_count - set_#{pagination_key} > 0 ? set_#{pagination_key} + 1 : nil) -%>"
        @context[:vars] ||= []
        @context[:vars] << "#{pagination_key}_next"
        out make_link(:default_text => "<%= set_#{pagination_key}_next %>", :query_params => {pagination_key => "[#{pagination_key}_next]"})
        if descendant('else')
          out expand_with(:in_if => true, :only => ['else', 'elsif'])
        end
        out "<% end -%>"
      when 'list'
        @context[:vars] ||= []
        @context[:vars] << "#{pagination_key}_page"
        if @blocks == [] || (@blocks.size == 1 && !@blocks.first.kind_of?(String) && @blocks.first.method == 'else')
          # add a default blocks
          if tag = @params[:tag]
            open_tag = "<#{tag}>"
            close_tag = "</#{tag}>"
          else
            open_tag = close_tag = ''
          end
          link_params = {}
          @params.each do |k,v|
            next if [:tag, :page, :join].include?(k)
            link_params[k] = v
          end
          text = "#{open_tag}<r:link #{params_to_html(link_params)} #{pagination_key}='[#{pagination_key}_page]' do='[#{pagination_key}_page]'/>#{close_tag}"
          @blocks = [make(:void, :method=>'void', :text=>text)]
          remove_instance_variable(:@all_descendants)
        end
        
        if !descendant('else')
          @blocks += [make(:void, :method=>'void', :text=>"<r:else>#{open_tag}<r:show var='#{pagination_key}_page'/>#{close_tag}</r:else>")]
          remove_instance_variable(:@all_descendants)
        end
        
        out "<% page_numbers(set_#{pagination_key}, set_#{pagination_key}_count, #{(@params[:join] || ' ').inspect}) do |set_#{pagination_key}_page, #{pagination_key}_page_join| %>"
        out "<%= #{pagination_key}_page_join %>"
        out "<% if set_#{pagination_key}_page != set_#{pagination_key} -%>"
        out expand_with
        out expand_with(:in_if => true, :only => ['else', 'elsif'])
        out "<% end; end -%>"
      else
        parser_error("unkown 'page' option #{@params[:page].inspect} should be ('previous', 'next' or 'list')")
      end
    end
    
    def r_img
      return unless node_kind_of?(Node)
      if @params[:src]
        finder, klass = build_finder_for(:first, @params[:src])
        return unless finder
        return parser_error("invalid class (#{klass})") unless klass.ancestors.include?(Node)
        img = finder
      else
        img = node
      end
      mode = @params[:mode] || 'std'
      # FIXME: replace this call by something that integrates better with html_tag_params and such.
      res = "img_tag(#{img}, :mode=>#{mode.inspect}"
      [:class, :alt_src, :id, :border, :style].each do |k|
        res  += ", :#{k}=>#{@params[k].inspect}" if @params[k]
      end
      res += ", :host => #{@context["exp_host"]}" if @context["exp_host"]
      res += ")"
      if @params[:link]
        finder, klass = build_finder_for(:first, @params[:link])
        return unless finder
        return parser_error("invalid class (#{klass})") unless klass.ancestors.include?(Node)
        
        opts_str = @context["exp_host"] ? ", :host => #{@context["exp_host"]}" : ""
        
        "<a href='<%= zen_path(#{finder}#{opts_str}) %>'><%= #{res} %></a>"
      else
        "<%= #{res} %>"
      end
    end
    
    # TODO: test
    def r_calendar
      if @context[:block] == self
        # called from self (storing template / rendering)
        size     = (params[:size]  || 'large').to_sym
        finder   = params[:select] || 'notes in project'
        ref_date = params[:date]   || 'event_at'
        type     = params[:type] ? params[:type].to_sym : :month
          
        if @blocks == []
          # add a default <r:link/> block
          if size == :tiny
            @blocks = [make(:void, :method=>'void', :text=>"<em do='link' date='current_date' do='[current_date]' format='%d'/><r:else do='[current_date]' format='%d'/>")]
          else
            @blocks = [make(:void, :method=>'void', :text=>"<span do='show' date='current_date' format='%d'/><ul><li do='each' do='link' attr='name'/></ul><r:else do='[current_date]' format='%d'/>")]
          end
          remove_instance_variable(:@all_descendants)
        elsif !descendant('else')
          @blocks += [make(:void, :method=>'void', :text=>"<r:else do='[current_date]' format='%d'/>")]
          remove_instance_variable(:@all_descendants)
        end
        @html_tag_done = false
        @html_tag_params[:id] = erb_dom_id
        @html_tag_params[:class] ||= "#{size}cal"
        @html_tag ||= 'div'
        
        case type
        when :month
          title = "\"\#{_(Date::MONTHNAMES[main_date.mon])} \#{main_date.year}\""
          prev_date = "\#{(main_date << 1).strftime(\"%Y-%m-%d\")}"
          next_date = "\#{(main_date >> 1).strftime(\"%Y-%m-%d\")}"
        when :week
          title = "\"\#{_(Date::MONTHNAMES[main_date.mon])} \#{main_date.year}\""
          prev_date = "\#{(main_date - 7).strftime(\"%Y-%m-%d\")}"
          next_date = "\#{(main_date + 7).strftime(\"%Y-%m-%d\")}"
        else
          return parser_error("invalid type (should be 'month' or 'week')")
        end
        
        finder, klass = build_finder_for(:all, finder, @params, [@date_scope])
        return unless finder
        return parser_error("invalid class (#{klass})") unless klass.ancestors.include?(Node)
        res = <<-END_TXT
<h3 class='title'>
<span><%= link_to_remote(#{_('img_prev_page').inspect}, :url => #{base_class.to_s.underscore}_path(#{node_id}) + \"/zafu?t_url=#{CGI.escape(template_url)}&dom_id=#{dom_id}&date=#{prev_date}\", :method => :get) %></span>
<span class='date'><%= link_to_remote(#{title}, :url => #{base_class.to_s.underscore}_path(#{node_id}) + \"/zafu?t_url=#{CGI.escape(template_url)}&dom_id=#{dom_id}\", :method => :get) %></span>
<span><%= link_to_remote(#{_('img_next_page').inspect}, :url => #{base_class.to_s.underscore}_path(#{node_id}) + \"/zafu?t_url=#{CGI.escape(template_url)}&dom_id=#{dom_id}&date=#{next_date}\", :method => :get) %></span>
</h3>
<table cellspacing='0' class='#{size}cal'>
  <tr class='head'><%= cal_day_names(#{size.inspect}) %></tr>
<% start_date, end_date = cal_start_end(#{current_date}, #{type.inspect}) -%>
<% cal_weeks(#{ref_date.to_sym.inspect}, #{finder}, start_date, end_date) do |week, cal_#{list_var}| -%>
  <tr class='body'>
<% week.step(week+6,1) do |day_#{list_var}|; #{list_var} = cal_#{list_var}[day_#{list_var}.strftime('%Y-%m-%d')] -%>
    <td<%= cal_class(day_#{list_var},#{current_date}) %>><% if #{list_var} -%>#{expand_with(:in_if => true, :list => list_var, :date => "day_#{list_var}", :saved_template => nil, :dom_prefix => nil)}<% end -%></td>
<% end -%>
  </tr>
<% end -%>
</table>
END_TXT
        render_html_tag(res)
      else
        fld = @params[:date] || 'event_at'
        fld = 'event_at' unless ['log_at', 'created_at', 'updated_at', 'event_at'].include?(fld)
      
        @date_scope = "TABLE_NAME.#{fld} >= '\#{start_date.strftime('%Y-%m-%d')}' AND TABLE_NAME.#{fld} <= '\#{end_date.strftime('%Y-%m-%d')}'"
        
        new_dom_scope
        
        # SAVED TEMPLATE
        template = expand_block(self, :block => self, :saved_template => true)
        out helper.save_erb_to_url(template, template_url)
        
        # INLINE
        out expand_block(self, :block => self, :saved_template => false)
      end
    end
    
    # part caching
    def r_cache
      kpath   = @params[:kpath]   || Page.kpath
      out "<% #{cache} = Cache.with(visitor.id, visitor.group_ids, #{kpath.inspect}, #{helper.send(:lang).inspect}, #{template_url.inspect}) do capture do %>"
      out expand_with
      out "<% end; end %><%= #{cache} %>"
    end
    
    # recursion
    def r_include
      return '' if @context[:saved_template]
      return super if @params[:template] || !@params[:part]
      part = @params[:part].gsub(/[^a-zA-Z_]/,'')
      method_name = @context["#{part}_method".to_sym]
      return parser_error("no parent named '#{part}'") unless method_name
      "<%= #{method_name}(depth+1,#{node},#{list}) %>"
    end
    
    # use all other tags as relations
    def r_unknown
      @params[:select] = @method
      r_context
    end
    
    # Enter a new context (<r:context find='all' method='pages'>). This is the same as '<r:pages>...</r:pages>'). It is
    # considered better style to use '<r:pages>...</r:pages>' instead of the more general '<r:context>' because the tags
    # give a clue on the context at start and end. Another way to open a context is the 'do' syntax: "<div do='pages'>...</div>".
    # FIXME: 'else' clause has been removed, find a solution to put it back.
    def r_context
      # DRY ! (build_finder_for, block)
      return parser_error("missing 'method' parameter") unless method = @params[:select]
      
      context = node_class.zafu_known_contexts[method]
      if context && @params.keys == [:select]
        open_context("#{node}.#{method}", context)
      elsif node_kind_of?(Node)
        count   = ['first','all','count'].include?(@params[:find]) ? @params[:find].to_sym : nil
        count ||= Node.plural_relation?(method) ? :all : :first
        finder, klass, query = build_finder_for(count, method, @params)
        return unless finder
        if node_kind_of?(Node) && !klass.ancestors.include?(Node)
          # moving out of node: store last Node
          @context[:previous_node] = node
        end
        if count == :all
          # plural
          do_list( finder, query, :node_class => klass)
        # elsif count == :count
        #   "<%= #{build_finder_for(count, method, @params)} %>"
        else
          # singular
          do_var(  finder, :node_class => klass)
        end
      else
        "unknown relation (#{method}) for #{node_class} class"
      end
    end
    
    def open_context(finder, context)
      klass = context[:node_class]
      # hack to store last 'Node' context until we fix node(Node) stuff:
      previous_node = node_kind_of?(Node) ? node : @context[:previous_node]
      if klass.kind_of?(Array)
        # plural
        do_list( finder, nil, context.merge(:node_class => klass[0], :previous_node => previous_node) )
      else
        # singular
        do_var(  finder, context.merge(:previous_node => previous_node) )
      end
    end
        
    # Prepare stylesheet and xml content for xsl-fo post-processor
    def r_fop
      return parser_error("missing 'stylesheet' argument") unless @params[:stylesheet]
      # get stylesheet text
      xsl_content, absolute_url, doc = self.class.get_template_text(@params[:stylesheet], @options[:helper], @options[:current_folder])
      return parser_error("stylesheet #{@params[:stylesheet].inspect} not found") unless doc
      
      template_url = (self.template_url.split('/')[0..-2] + ['_main.xsl']).join('/')
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
    
    def r_debug
      return '' unless @context[:dev]
      add_html_class('debug')
      out "<p>#{@params[:title]}</p>" if @params[:title]
      (@params[:show] || '').split(',').map(&:strip).each do |what|
        case what
        when 'params'
          out "<pre><%= params.inspect %></pre>"
        else
          parser_error("invalid element to show. Options are ['params'].")
        end
      end
      out expand_with
    end
    
    # ================== HELPER METHODS ================
    
    # Create an sql query to open a new context (passes its arguments to HasRelations#build_find)
    def build_finder_for(count, rel, params=@params, raw_filters = [])
      if (context = node_class.zafu_known_contexts[rel]) && !params[:in] && !params[:where] && !params[:from] && !params[:order] && raw_filters == []
        klass = context[:node_class]
        
        if klass.kind_of?(Array) && count == :all
          return ["#{node}.#{rel}", klass[0]]
        else
          return [(count == :all ? "[#{node}.#{rel}]" : "#{node}.#{rel}"), klass]
        end
      end
      
      rel ||= 'self'
      if (count == :first)
        if rel == 'self'
          return [node, node_class]
        elsif rel == 'main'
          return ["@node", Node]
        elsif rel == 'root'
          return ["(secure(Node) { Node.find(#{current_site[:root_id]})})", Node]
        elsif rel == 'visitor'
          return ["visitor.contact", Node]
        elsif rel =~ /^\d+$/
          return ["(secure(Node) { Node.find_by_zip(#{rel.inspect})})", Node]
        elsif node_name = find_stored(Node, rel)
          return [node_name, Node]
        elsif rel[0..0] == '/'
          rel = rel[1..-1]
          return ["(secure(Node) { Node.find_by_path(#{rel.inspect})})", Node]
        end
      end
      
      pseudo_sql, add_raw_filters = make_pseudo_sql(rel, params)
      raw_filters += add_raw_filters if add_raw_filters
      
      # FIXME: stored should be clarified and managed in a single way through links and contexts.
      # <r:void store='foo'>...
      # <r:link href='foo'/>
      # <r:pages from='foo'/> <-- this is just a matter of changing node parameter
      # <r:pages from='site' project='foo'/>
      # <r:img link='foo'/>
      # ...
      
      if node_kind_of?(Node)
        node_name = @context[:parent_node] || node
      else
        node_name = @context[:previous_node]
      end
      
      # make sure we do not use a new record in a find query:
      query = Node.build_find(count, pseudo_sql, :node_name => node_name, :raw_filters => raw_filters, :ref_date => "\#{#{current_date}}")
      
      unless query.valid?
        out parser_error(query.errors.join(' '), pseudo_sql.join(', '))
        return nil
      end
      
        
      if count == :count
        out "<%= #{query.finder(:count)} %>"
        return nil
      end
      
      klass = query.main_class
      
      if params[:else]
        # FIXME: else not working with zafu_known_contexts
        finder, else_class, else_query = build_finder_for(count, params[:else], {})
        if finder && (else_query.nil? || else_query.valid?) && (else_class == klass || klass.ancestors.include?(else_class) || else_class.ancestors.include?(klass))
          ["(#{query.finder(count)} || #{finder})", klass, query]
        else
          [query.finder(count), query.main_class, query]
        end
      else
        [query.finder(count), query.main_class, query]
      end
    end
    
    # Build pseudo sql from the parameters
    # comments where ... from ... in ... order ... limit
    def make_pseudo_sql(rel, params=@params)
      parts   = [rel.dup]
      filters = []
      
      if params[:from]
        parts << params[:from]
        
        key_counter = 1
        while sub_part = params["from#{key_counter}".to_sym]
          key_counter += 1
          parts << sub_part
        end
      end
      
      if params[:where]
        parts[0] << " where #{params[:where]}"
      end
      
      if params[:in]
        parts[-1] << " in #{params[:in]}"
      end
      
      if group = params[:group]
        parts[-1] << " group by #{group}" unless parts[0] =~ /group by/
      end
      
      if order = params[:order]
        parts[-1] << " order by #{order}" unless parts[0] =~ /order by/
      end
      
      if paginate = params[:paginate]
        page_size = params[:limit].to_i
        page_size = 20 if page_size < 1
        parts[-1] << " limit #{page_size} paginate #{paginate.gsub(/[^a-z_A-Z]/,'')}"
      else
        [:limit, :offset].each do |k|
          next unless params[k]
          parts[-1] << " #{k} #{params[k]}" unless parts[0] =~ / #{k} /
        end
      end
      
      finders = [parts.join(' from ')]
      if params[:or]
        finders << params[:or]
        
        key_counter = 1
        while sub_or = params["or#{key_counter}".to_sym]
          key_counter += 1
          finders << sub_or
        end
      else
        or_clause = nil
      end
      
      return [finders, parse_raw_filters(params)]
    end
    
    # Parse special filters
    def parse_raw_filters(params)
      filters = []
      
      if value = params[:author]
        if stored = find_stored(User, value)
          filters << "TABLE_NAME.user_id = '\#{#{stored}.id}'"
        elsif value == 'current'
          filters << "TABLE_NAME.user_id = '\#{#{node}[:user_id]}'"
        elsif value == 'visitor'
          filters << "TABLE_NAME.user_id = '\#{visitor[:id]}'"
        elsif value =~ /\A\d+\Z/
          filters << "TABLE_NAME.user_id = '#{value.to_i}'"
        elsif value =~ /\A[\w\/]+\Z/
          # TODO: path, not implemented yet
        end
      end
      
      if value = params[:project]
        if stored = find_stored(Node, value)
          filters << "TABLE_NAME.project_id = '\#{#{stored}.get_project_id}'"
        elsif value == 'current'
          filters << "TABLE_NAME.project_id = '\#{#{node}.get_project_id}'"
        elsif value =~ /\A\d+\Z/
          filters << "TABLE_NAME.project_id = '#{value.to_i}'"
        elsif value =~ /\A[\w\/]+\Z/
          # TODO: path, not implemented yet
        end
      end
      
      if value = params[:section]
        if stored = find_stored(Node, value)
          filters << "TABLE_NAME.section_id = '\#{#{stored}.get_section_id}'"
        elsif value == 'current'
          filters << "TABLE_NAME.section_id = '\#{#{node}.get_section_id}'"
        elsif value =~ /\A\d+\Z/
          filters << "TABLE_NAME.section_id = '#{value.to_i}'"
        elsif value =~ /\A[\w\/]+\Z/
          # not implemented yet
        end
      end
      
      [:updated, :created, :event, :log].each do |k|
        if value = params[k]
          # current, same are synonym for 'today'
          filters << Node.connection.date_condition(value,"TABLE_NAME.#{k}_at",current_date)
        end
      end

      filters == [] ? nil : filters
    end
    
    # helpers
    # get current output format
    def output_format
      @context[:output_format] || 'html'
    end
    
    # find the current node name in the context
    def node(klass = self.node_class)
      if klass == self.node_class
        (@context[:saved_template] && @context[:main_node]) ? "@#{base_class.to_s.underscore}" : (@context[:node] || '@node')
      elsif klass == Node
        @context[:previous_node] || '@node'
      else
        # ?
        out parser_error("could not find node_name for #{klass} (current class is #{node_class})")
        '@node'
      end
    end

    def erb_node_id(obj = node)
      if node_kind_of?(Version)
        "<%= #{obj}.node.zip %>.<%= #{obj}.number %>"
      else
        "<%= #{node_id(obj)} %>"
      end
    end
    
    def node_id(obj = node)
      "#{obj}.zip"
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
    
    # Class of the current 'node' object (can be Version, Comment, Node, DataEntry, etc)
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
    
    def params_to_erb(params, initial_comma = true)
      res = initial_comma ? [""] : []
      params.each do |k,v|
        if v =~ /<%=/ && !(v =~ /"/)
          # replace by #{}
          val = v.gsub('#{', '# {').gsub(/<%=(.*?)%>/,'#{\1}')
          res << "#{k.inspect}=>\"#{val}\""
        else
          res << "#{k.inspect}=>#{v.inspect}"
        end
      end
      res.join(', ')
    end
    
    def do_var(var_finder=nil, opts={})
      clear_dom_scope
      if var_finder == 'nil'
        out "<% if nil -%>"
      elsif var_finder
        out "<% if #{var} = #{var_finder} -%>"
      end
      
      if descendant('unlink')
        @html_tag ||= 'div'
        new_dom_scope
        @html_tag_params[:id] = erb_dom_id
      end
      
      res = expand_with(opts.merge(:node=>var, :in_if => false))
      
      if var_finder
        res += expand_with(opts.merge(:in_if => true, :only => ['else', 'elsif'], :html_tag_params => @html_tag_params, :html_tag => @html_tag))
      end
      out render_html_tag(res)
      out "<% end -%>" if var_finder
    end
    
    def do_list(list_finder, query = nil, opts={})
      clear_dom_scope
      
      @context.merge!(opts)          # pass options from 'zafu_known_contexts' to @context
      
      if (each_block = descendant('each')) && (each_block.descendant('edit') || descendant('add') || descendant('add_document') || (descendant('swap') && descendant('swap').parent.method != 'block') || ['block', 'drop'].include?(each_block.single_child_method))
        new_dom_scope
        # ajax, build template. We could merge the following code with 'r_block'.
        add_block  = descendant('add')
        form_block = descendant('form') || each_block
        
        @context[:need_link_id] = form_block.need_link_id
        
        out "<% if (#{list_var} = #{list_finder}) || (#{node}.#{node_kind_of?(Comment) ? "can_comment?" : "can_write?"} && #{list_var}=[]) -%>"
        if query && (pagination_key = query.pagination_key)
          out "<% set_#{pagination_key}_nodes = #{query.finder(:count)}; set_#{pagination_key}_count = (set_#{pagination_key}_nodes / #{query.page_size.to_f}).ceil; set_#{pagination_key} = [1,params[:#{pagination_key}].to_i].max -%>"
          @context[:paginate] = pagination_key
          @context[:vars] ||= []
          @context[:vars] << "#{pagination_key}_nodes"
          @context[:vars] << "#{pagination_key}_count"
          @context[:vars] << "#{pagination_key}"
        end
        
        # should we publish ?
        publish_after_save ||= form_block ? form_block.params[:publish] : nil
        publish_after_save ||= descendant('edit') ? descendant('edit').params[:publish] : nil
        
        # class name for create form
        klass       = add_block  ? add_block.params[:klass]  : nil
        klass     ||= form_block ? form_block.params[:klass] : nil
        
        # INLINE ==========
        # 'r_add' needs the form when rendering. Send with :form.
        res = expand_with(:list=>list_var, :form=>form_block, :publish_after_save => publish_after_save, :ignore => ['form'], :klass => klass, :in_if => true)
        out render_html_tag(res)
        # what about 'else' ?
        out "<% end -%>"

        # SAVED TEMPLATE ========
        template      = expand_block(each_block, :list=>false, :klass => klass, :saved_template => true)
        out helper.save_erb_to_url(template, template_url)
        
        # FORM ============
        if each_block != form_block
          form = expand_block(form_block, :klass => klass, :add=>add_block, :publish_after_save => publish_after_save, :saved_template => true)
        else
          form = expand_block(form_block, :klass => klass, :add=>add_block, :make_form=>true, :publish_after_save => publish_after_save, :saved_template => true)
        end
        out helper.save_erb_to_url(form, form_url)
      else
        # no form, render, edit and add are not ajax
        if descendant('add') || descendant('add_document')
          out "<% if (#{list_var} = #{list_finder}) || (#{node}.#{node_kind_of?(Comment) ? "can_comment?" : "can_write?"} && #{list_var}=[]) -%>"
        elsif list_finder != 'nil'
          out "<% if #{list_var} = #{list_finder} -%>"
        else
          out "<% if nil -%>"
        end
        
        if query && (pagination_key = query.pagination_key)
          out "<% set_#{pagination_key}_nodes = #{query.finder(:count)}; set_#{pagination_key}_count = (set_#{pagination_key}_nodes / #{query.page_size.to_f}).ceil; set_#{pagination_key} = [1,params[:#{pagination_key}].to_i].max -%>"
          @context[:paginate] = pagination_key
          @context[:vars] ||= []
          @context[:vars] << "#{pagination_key}_nodes"
          @context[:vars] << "#{pagination_key}_count"
          @context[:vars] << "#{pagination_key}"
        end
        
        res = expand_with(:list=>list_var, :in_if => true)
        out render_html_tag(res)
        out "<% end -%>"
      end
    end
    
    def _(text)
      if @context[:dict]
        @context[:dict][text] || helper.send(:_,text)
      else
        helper.send(:_,text)
      end  
    end
    
    # Find a block to update on the page
    def find_target(name)
      # find dom_id / template_url
      target = nil
      root.descendants('block').each do |b|
        if b.name == name
          target = b
          break
        end
      end
      out parser_error("could not find a block named '#{name}'") if target.nil?
      target
    end
    
    # DOM id for the current context
    def dom_id(suffix='')
      return "\#{dom_id(#{node})}" if @context && (@context[:saved_template] && @context[:main_node])
      if @context && scope_node = @context[:scope_node]
        res = "#{dom_prefix}_\#{#{scope_node}.zip}"
      else
        res = dom_prefix
      end
      if (method == 'each' || method == 'each_group') && !@context[:make_form]
        "#{res}_\#{#{var}.zip}"
      elsif method == 'unlink' || method == 'edit'
        target = nil
        parent = self.parent
        while parent
          if ['block', 'each', 'context', 'icon'].include?(parent.method)
            target = parent
            break
          end
          parent = parent.parent
        end
        target ? target.dom_id(suffix) : (res + suffix)
      else
        res + suffix
      end
    end
    
    def erb_dom_id(suffix='')
      return "<%= dom_id(#{node}) %>" if @context && (@context[:saved_template] && @context[:main_node])
      if @context && scope_node = @context[:scope_node]
        res = "#{dom_prefix}_<%= #{scope_node}.zip %>"
      else
        res = dom_prefix
      end
      if (method == 'each' || method == 'each_group') && !@context[:make_form]
        "#{res}_<%= #{var}.zip %>"
      elsif method == 'draggable'
        "#{res}_<%= #{node}.zip %>"
      elsif method == 'unlink'
        target = nil
        parent = self.parent
        while parent
          if ['block', 'each', 'context', 'icon'].include?(parent.method)
            target = parent
            break
          end
          parent = parent.parent
        end
        target ? target.erb_dom_id(suffix) : (res + suffix)
      else
        res + suffix
      end
    end
    
    # Unique template_url, ending with dom_id
    def template_url
      "#{@options[:root]}/#{dom_prefix}"
    end
    
    def form_url
      template_url + '_form'
    end
    
    # Return parameter value accessor
    def get_param(key)
      "params[:#{key}]"
    end
    
    def context
      return @context if @context
      # not rendered yet, find first parent with context
      @context = parent ? parent.context : {}
    end
    
    # prefix for DOM id
    def dom_prefix
      (@context ? @context[:dom_prefix] : nil) || (@dom_prefix ||= unique_name)
    end
    
    # use our own scope
    def clear_dom_scope
      @context.delete(:make_form)      # should not propagate
      @context.delete(:main_node)      # should not propagate
    end
    
    # create our own ajax DOM scope
    def new_dom_scope
      clear_dom_scope
      @context.delete(:saved_template) # should not propagate on fresh template
      @context.delete(:dom_prefix)     # should not propagate on fresh template
      @context[:main_node]  = true     # the current context will be rendered with a fresh '@node'
      @context[:dom_prefix] = self.dom_prefix
    end
    
    # Return a different name on each call
    def unique_name(base = context_name)
      root.next_name_index(base, base == @name).gsub(/[^\d\w\/]/,'_')
    end
    
    def context_name
      @name || if @context
        @context[:name] || 'list'
      elsif parent
        parent.context_name
      else
        'root'
      end
    end
    
    def next_name_index(key, own_id = false)
      @next_name_index ||= {}
      if @next_name_index[key]
        @next_name_index[key] += 1
        key + @next_name_index[key].to_s
      elsif own_id
        @next_name_index[key] = 0
        key
      else
        @next_name_index[key] = 1
        key + '1'
      end
    end
       
    def add_params(text, opts={}, inner = '')
      text.sub(/\A([^<]*)<(\w+)(( .*?)[^%]|)>/) do
        # we must set the first tag id
        before = $1
        tag = $2
        params = parse_params($3)
        opts.each do |k,v|
          next unless v
          params[k] = v
        end
        "#{before}<#{tag}#{params_to_html(params)}>#{inner}"
      end
    end
    
    def get_test_condition(node = self.node, params = @params)
      tests = []
      params.each do |k,v|
        if k.to_s =~ /^(or_|)([a-zA-Z_]+)(\d*)$/
          k = $2.to_sym
        end
        if [:kind_of, :klass, :status, :lang, :can, :node, :in, :visitor, :has].include?(k)
          tests << [k, v]
        elsif k == :test
          if v =~ /\s/
            tests << [:test, v]
          else
            tests << [:attribute, v]
          end
        end
      end
      
      
      tests.map! do |type,value|
        case type
        when :kind_of
        "#{node}.vkind_of?(#{value.inspect})"
        when :klass
          klass = begin Module::const_get(value) rescue "NilClass" end
          "#{node}.klass == #{value.inspect}"
        when :status
          "#{node}.version.status == #{Zena::Status[value.to_sym]}"
        when :lang
          "#{node}.version.lang == #{value.inspect}"
        when :can
          # TODO: test
          case value
          when 'write', 'edit'
            "#{node}.can_write?"
          when 'drive', 'publish'
            "#{node}.can_drive?"
          else
            nil
          end
        when :has
          case value
          when 'discussion'
            "#{node}.discussion"
          else
            nil
          end
        when :test
          if value =~ /("[^"]*"|'[^']*'|[\w:\.\-]+)\s*(>=|<=|<>|<|=|>|lt|le|eq|ne|ge|gt)\s*("[^"]*"|'[^']*'|[\w:\.\-]+)/
            parts = [$1,$3]
            op = {'lt' => '<','le' => '<=','eq' => '==', '=' => '==','ne' => '!=','ge' => '>=','gt' => '>'}[$2] || $2
            toi   = ( op =~ /(>|<)/ || (parts[0] =~ /^-?\d+$/ || parts[1] =~ /^-?\d+$/) )
            parts.map! do |part|
              if ['"',"'"].include?(part[0..0])
                toi ? part[1..-2].to_i : part[1..-2].inspect
              elsif part == 'NOW'
                "Time.now.to_i"
              elsif part =~ /^-?\d+$/
                part
              else
                if node_attr = node_attribute(part, :node => node)
                  toi ? "#{node_attr}.to_i" : "#{node_attr}.to_s"
                else
                  nil
                end
              end
            end
            
            parts.include?(nil) ? nil :  "#{parts[0]} #{op} #{parts[1]}"
          else
            nil
          end
        when :attribute
          '!' + node_attribute(value, :node => node) + '.blank?'
        when :node
          if node_kind_of?(Node)
            value, node_name = get_attribute_and_node(value)
            node_name ||= '@node'
            if value
              case value
              when 'main'
                "#{node}[:id] == #{node_name}[:id]"
              when 'start'
                "#{node}[:zip] == (params[:s] || @node[:zip]).to_i"
              when 'parent'
                "#{node}[:id] == #{node_name}[:parent_id]"
              when 'project'
                "#{node}[:id] == #{node_name}[:project_id]"
              when 'section'
                "#{node}[:id] == #{node_name}[:section_id]"
              when 'ancestor'
                "#{node_name}.fullpath =~ /\\A\#{#{node}.fullpath}/"
              else
                if stored = find_stored(Node, value)
                  "#{node}[:id] == #{stored}[:id]"
                else
                  nil
                end
              end
            else
              # bad node_name
              nil
            end
          else
            nil
          end  
        when :in
          if @context["in_#{value}".to_sym] || ancestors.include?(value)
            'true'
          else
            'false'
          end
        when :visitor
          if value == 'anon'
            "visitor.is_anon?"
          else
            nil
          end
        else
          nil
        end
      end.compact!
      tests == [] ? nil : tests.join(' || ')
    end
    
    # Block visibility of descendance with 'do_list'.
    def public_descendants
      all = super
      if ['context', 'each', 'block'].include?(self.method)
        # do not propagate 'form',etc up
        all.reject do |k,v|
          ['form','unlink'].include?(k)
        end
      elsif ['if', 'case'].include?(self.method)
        all.reject do |k,v|
          ['else', 'elsif', 'when'].include?(k)
        end
      else
        all
      end
    end
    
    def single_child_method
      return @single_child_method if defined?(@single_child_method)
      @single_child_method = if @blocks.size == 1
        single_child = @blocks[0]
        return nil if single_child.kind_of?(String)
        single_child.html_tag ? nil : single_child.method
      else
        nil
      end
    end
    
    def get_attribute_and_node(str)
      if str =~ /([^\.]+)\.(.+)/
        node_name = $1
        node_attr = $2
        if att_node = find_stored(Node, node_name)
          return [node_attr, att_node, Node]
        elsif node_name == 'main'
          return [node_attr, '@node', Node]
        elsif node_name == 'visitor'
          return [node_attr, 'visitor.contact', Contact]
        elsif node_name == 'site'
          return [node_attr, 'current_site', Site]
        else
          out parser_error("invalid node name #{node_name.inspect} in attribute #{str.inspect}")
          return [nil]
        end
      else
        return [str]
      end
    end
    
    def parse_attributes_in_value(v, opts = {})
      opts = {:erb => true}.merge(opts)
      static = true
      
      use_node  = @var || node
      res = v.gsub(/\[([^\]]+)\]/) do
        static = false
        res    = nil
        attribute = $1
        
        if opts[:skip_node_attributes]
          if attribute =~ /^param:(\w+)$/
            attribute = get_param($1)
          elsif attribute == 'current_date'
            attribute = current_date
          else
            res = "[#{attribute}]"
          end
        else
          attribute = node_attribute(attribute, :node => use_node )
        end
        
        res ||= if opts[:erb]
          "<%= #{attribute} %>"
        else
          "\#{#{attribute}}"
        end
        res
      end
      [res, static]
    end
    
    def node_attribute(str, opts={})
      if @context[:vars] && @context[:vars].include?(str)
        return "set_#{str}"
      end
      
      return "(params[:s] || @node[:zip]).to_i" if str == 'start.id'
      attribute, att_node, klass = get_attribute_and_node(str)
      return 'nil' unless attribute
      return get_param($1) if attribute =~ /^param:(\w+)$/
      return current_date if attribute == 'current_date'
      
      
      att_node  ||= opts[:node]       || node
      klass     ||= opts[:node_class] || node_class
      
      real_attribute = attribute =~ /\Ad_/ ? attribute : attribute.gsub(/\A(|[\w_]+)id(s?)\Z/, '\1zip\2')
      
      res = if klass.ancestors.include?(Node)
        if ['url','path'].include?(real_attribute)
          # pseudo attribute 'url'
          params = {}
          params[:mode]   = @params[:mode]   if @params[:mode]
          params[:format] = @params[:format] if @params[:format]
          "zen_#{real_attribute}(#{node}#{params_to_erb(params)})"
        else
          Node.zafu_attribute(att_node, real_attribute)
        end
        # FIXME: replace theses tests by "klass.zafu_readable?(real_attribute)" and make sure it works for sub-classes.
      elsif klass.ancestors.include?(Version) && Version.zafu_readable?(real_attribute)
        "#{att_node}.#{real_attribute}"
      elsif klass.ancestors.include?(DataEntry) && DataEntry.zafu_readable?(real_attribute)
        "#{att_node}.#{real_attribute}"
      elsif klass.ancestors.include?(Comment) && Comment.zafu_readable?(real_attribute)
        "#{att_node}.#{real_attribute}"
      elsif klass.ancestors.include?(ActiveRecord::Base) && klass.zafu_readable?(real_attribute)
        "#{att_node}.#{real_attribute}"
      else
        # unknown class, resolve at runtime
        "#{att_node}.zafu_read(#{real_attribute.inspect})"
      end
      
      res = "(#{res} || #{node_attribute(opts[:else])})" if opts[:else]
      res = "(#{res} || #{opts[:default].inspect})" if opts[:default]
      res
    end
    
    # Add a class name to the html_tag
    def add_html_class(class_name)
      if klass = @html_tag_params[:class]
        @html_tag_params[:class] = "#{class_name} #{klass}"
      else
        @html_tag_params[:class] = class_name
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
      if node_kind_of?(Node)
        
        if @context[:make_form]
          node_name = node
        elsif (@method == 'each' || @method == 'each_group') && @context[:list]
          node_name = var
        elsif @method == 'context'
          node_name = @var || node
        else
          node_name = node
        end
        
        @params.each do |k,v|
          if k.to_s =~ /^(.+)_if$/
            klass = $1
            cond  = get_test_condition(node_name, :test => v)
          elsif k.to_s =~ /^(.+)_if_(test|node|kind_of|klass|status|lang|can|in)$/
            klass = $1
            cond  = get_test_condition(node_name, $2.to_sym => v)
          end
          if cond
            append << "<%= #{cond} ? \" class='#{klass}'\" : \"#{tag_class ? " class='#{tag_class}'" : ""}\" %>"
            @html_tag_params.delete(:class)
          end
        end
      end
      
      @html_tag = 'div' if !@html_tag && (set_params != {} || @html_tag_params != {})
      
      bak = @html_tag_params.dup
      @html_tag_params = get_html_params(set_params.merge(@html_tag_params), @html_tag)
      res = super(text,*append)
      @html_tag_params = bak
      res
    end
    
    def link_to_update(target, opts = {})
      method = opts[:method] || :get
      
      html_params = opts[:html_params] || {}
      node_id = opts[:node_id] || self.node_id
      
      url    = opts[:url]    || "/#{base_class.to_s.pluralize.underscore}/\#{#{node_id}}#{method == :get ? '/zafu' : ''}"
      opts[:cond]   ||= "#{node}.can_write?" if method != :get
      
      query_params = [opts[:query_params]].flatten.compact
      
      if method == :get
        if target
          query_params << "t_url=#{CGI.escape(target.template_url)}" 
          query_params << "dom_id=#{target.dom_id}"
        else
          query_params << "dom_id=_page"
        end
      else
        query_params << "t_url=#{CGI.escape(template_url)}" if method != :delete
        
        query_params << "dom_id=#{dom_id}"
        if target != self
          if target
            query_params << "u_url=#{CGI.escape(target.template_url)}"
            query_params << "udom_id=#{target.dom_id}"
          else
            query_params << "udom_id=_page"
          end
        end
      end
      
      query_params << "link_id=\#{#{node}.link_id}" if @context[:need_link_id] && node_kind_of?(Node)
      query_params << "node[v_status]=#{Zena::Status[:pub]}" if @params[:publish]
      query_params << start_node_s_param(:string)
      
      res = ''
      res += "<% if #{opts[:cond]} -%>" if opts[:cond]
      res += "<%= tag_to_remote({:url => \"#{url}?#{query_params.join('&')}\", :method => #{method.inspect}}#{params_to_erb(html_params)}) %>"
      res += text_for_link(opts[:default_text])
      res += "</a>"
      if opts[:cond]
        if opts[:else] != :void
          res += "<% else -%>"
          res += text_for_link(opts[:default_text])
        end
        res += "<% end -%>"
      end
      res
    end
    
    def text_for_link(default = nil)
      if @blocks.size > 1 || (@blocks.size == 1 && !(@blocks.first.kind_of?(String) || ['else','elsif'].include?(@blocks.first.method)))
        expand_with
      elsif default
        default
      elsif erb_text = get_text_for_erb(@params, false, :string)
        erb_text
      elsif node_kind_of?(Node)
        "<%= #{node}.v_title %>"
      elsif node_kind_of?(Version)
        "<%= #{node}.title %>"
      elsif node_kind_of?(Link)
        "<%= #{node}.name %>"
      else
        _('edit')
      end
    end
    
    def get_text_for_erb(params = @params, use_blocks = true, context = :erb)
      string_context = context == :string
      if params[:attr]
        string_context ? "<%= #{node_attribute(params[:attr])} %>" : node_attribute(params[:attr])
      elsif params[:tattr]
        string_context ? "<%= _(#{node_attribute(params[:tattr])}) %>" : "_(#{node_attribute(params[:tattr])})"
      elsif params[:trans]
        string_context ? _(params[:trans]) : _(params[:trans]).inspect
      elsif params[:text]
        string_context ? params[:text] : params[:text].inspect
      elsif use_blocks && @blocks != []
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
          string_context ? text : text.inspect
        else
          # function(...) + "blah" + function()
          string_context ? "<%= #{res.join(' + ')} %>" : res.join(' + ')
        end
      else
        nil
      end
    end
    
    def get_input_params(params = @params)
      res = {}
      unless res[:name] = (params[:name] || params[:date])
        return [{}, nil]
      end
      
      if res[:name] =~ /\A([\w_]+)\[(.*?)\]/
        attribute = $2
      else
        attribute = res[:name]
        if @context[:in_filter] || attribute == 's'
          res[:name] = attribute
        else
          res[:name] = "#{base_class.to_s.underscore}[#{attribute}]"
        end
      end 
      
      if @context[:dom_prefix]
        res[:id]   = "#{erb_dom_id}_#{attribute}"
      else
        res[:id]   = params[:id] if params[:id]
      end
      
      [:size, :style, :class].each do |k|
        res[k] = params[k] if params[k]
      end
      
      if @context[:in_add]
        res[:value] = (params[:value] || params[:set_value]) ? ["'#{ helper.fquote(params[:value])}'"] : ["''"]
      elsif @context[:in_filter]
        res[:value] = attribute ? ["'<%= fquote params[#{attribute.to_sym.inspect}] %>'"] : ["''"]
      else
        res[:value] = attribute ? ["'<%= fquote #{node_attribute(attribute)} %>'"] : ["''"]
      end
      return [res, attribute]
    end
    
    def get_html_params(params, tag_type)
      res  = {}
      params.each do |k,v|
        next unless v
        if k.to_s =~ /\A(t?)set_(.+)$/
          key   = $2
          trans = $1 == 't'
          value, static = parse_attributes_in_value(v, :erb => !trans)

          if trans
            if static
              value = ["'#{_(value)}'"]            # array so it is not escaped on render
            else
              value = ["'<%= _(\"#{value}\") %>'"] # FIXME: use dict ! array so it is not escaped on render
            end
          end
          res[key.to_sym] = value
        elsif tag_type == :link && ![:style, :class, :id, :title].include?(k)
          # bad html parameter for links (some keys for link tags are used as query parameters)
          # filter out
        else
          res[k] ||= v
        end
      end
      
      if params[:anchor]
        @anchor_param = nil
        res[:name] = anchor_name(params[:anchor], node)
      end
      
      res
    end
    
    def get_options_for_select
      if nodes = @params[:nodes]
        # TODO: dry with r_checkbox
        if nodes =~ /^\d+\s*($|,)/
          # ids
          # TODO: optimization generate the full query instead of using secure.
          nodes = nodes.split(',').map{|v| v.to_i}
          nodes = "(secure(Node) { Node.find(:all, :conditions => 'zip IN (#{nodes.join(',')})') })"
        else
          # relation
          nodes, klass = build_finder_for(:all, nodes)
          return unless nodes
          return parser_error("invalid class (#{klass})") unless klass.ancestors.include?(Node)
        end  
        set_attr  = @params[:attr] || 'id'
        show_attr = @params[:show] || 'name'
        options_list = "[['','']] + (#{nodes} || []).map{|r| [#{node_attribute(show_attr, :node => 'r', :node_class => Node)}, #{node_attribute(set_attr, :node => 'r', :node_class => Node)}.to_s]}"
      elsif values = @params[:values]
        options_list = values.split(',').map(&:strip)
        
        if show = @params[:show]
          show_values = show.split(',').map(&:strip)
        elsif show = @params[:tshow]
          show_values = show.split(',').map do |s|
            _(s.strip)
          end
        end
        
        if show_values
          options_list.each_index do |i|
            options_list[i] = [show_values[i], options_list[i]]
          end
        end
        options_list.inspect
      end
    end
    
    def parse_eval_parameter(str)
      # evaluate an expression. Can only contain vars, '(', ')', '*', '+', '/', '-', '[attr]'
      # FIXME: SECURITY (audit this)
      vars = @context[:vars] || []
      parts = str.split(/\s+/)
      res  = []
      test = []
      parts.each do |p|
        if p =~ /\[([\w_]+)\]/
          test << 1
          res << (node_attribute($1) + '.to_f')
        elsif p =~ /^[a-zA-Z_]+$/
          unless vars.include?(p)
            out parser_error("var #{p.inspect} not set in eval") 
            return nil
          end
          test << 1
          res  << "set_#{p}.to_f"
        elsif ['(', ')', '*', '+', '/', '-'].include?(p)
          res  << p
          test << p
        elsif p =~ /^[0-9\.]+$/
          res  << p
          test << p
        else
          out parser_error("bad argument #{p.inspect} in eval")
          return nil
        end
      end
      begin
        begin
          eval test.join(' ')
        rescue
          # rescue evaluation error
          out parser_error("error in eval")
          return nil
        end
        "(#{res.join(' ')})"
      rescue SyntaxError => err
        # rescue compilation error
        out parser_error("compilation error in eval")
        return nil
      end
    end
    
    def find_stored(klass, key)
      if "#{klass}_#{key}" == "Node_start_node"
        # main node before ajax stuff (the one in browser url)
        "start_node"
      else
        @context["#{klass}_#{key}"]
      end
    end
    
    def set_stored(klass, key, obj)
      @context["#{klass}_#{key}"] = obj
    end

    # transform a 'show' tag into an input field.
    def make_input(params = @params)
      input, attribute = get_input_params(params)
      return parser_error("missing 'name'") unless attribute
      return '' if attribute == 'parent_id' # set with 'r_form'
      return '' if ['url','path'].include?(attribute) # cannot be set with a form
      if params[:date]
      input_id = @context[:dom_prefix] ? ", :id=>\"#{dom_id}_#{attribute}\"" : ''
        return "<%= date_box('#{base_class.to_s.underscore}', #{params[:date].inspect}#{input_id}) %>"
      end
      input_id = @context[:dom_prefix] ? " id='#{erb_dom_id}_#{attribute}'" : ''
      "<input type='#{params[:type] || 'text'}'#{input_id} name='#{input[:name]}' value=#{input[:value]}/>"
    end
    
    # transform a 'zazen' tag into a textarea input field.
    def make_textarea(params)
      return parser_error("missing 'name'") unless name = params[:name]
      if name =~ /\A([\w_]+)\[(.*?)\]/
        attribute = $2
      else
        attribute = name
        name = "#{base_class.to_s.underscore}[#{attribute}]"
      end
      return '' if attribute == 'parent_id' # set with 'r_form'
      
      if @blocks == [] || @blocks == ['']
        if @context[:in_add]
          value = ''
        else
          value = attribute ? "<%= #{node_attribute(attribute)} %>" : ""
        end
      else
        value = expand_with
      end
      html_id = @context[:dom_prefix] ? " id='#{erb_dom_id}_#{attribute}'" : ''
      "<textarea#{html_id} name='#{name}'>#{value}</textarea>"
    end
    
    def default_focus_field
      if (input_fields = descendants('input')) != []
        field = input_fields.first.params[:name]
      elsif (show_fields = descendants('show')) != []
        field = show_fields.first.params[:attr]
      elsif node_kind_of?(Node)
        field = 'v_title'
      else
        field = 'text'
      end
    end
    
    # Returns true if a form/edit needs to keep track of link_id (l_status or l_comment used).
    def need_link_id
      if (input_fields = (descendants('input') + descendants('select'))) != []
        input_fields.each do |f|
          return true if f.params[:name] =~ /\Al_/
        end
      elsif (show_fields = descendants('show')) != []
        show_fields.each do |f|
          return true if f.params[:attr] =~ /\Al_/
        end
      end
      return false
    end
    
    def start_node_s_param(type = :input)
      if type == :input
        "<input type='hidden' name='s' value='<%= params[:s] || @node[:zip] %>'/>"
      elsif type == :erb
        "s=<%= params[:s] || @node[:zip] %>"
      elsif type == :value
        "<%= params[:s] || @node[:zip] %>"
      else
        "s=\#{params[:s] || @node[:zip]}"
      end
    end
    
    def parser_error(message, tag=@method)
      "<span class='parser_error'>[#{tag}] #{message}</span>"
    end
    
    # Used by [each] and [draggable] to insert 'id' and drag handle span
    def set_drag_handle_and_id(text, params, id_hash)
      res, drag_handle = text, nil
      if params[:drag_handle]
        drag_handle = params[:drag_handle] == 'true' ? 'drag_handle' : params[:drag_handle]
        if text =~ /class\s*=\s*['"]#{drag_handle}/
          # nothing to do
          insert = ''
        else
          insert = "<span class='#{drag_handle}'>&nbsp;</span>"
        end
      else
        insert = ''
      end  

      res = insert + text
      
      if id_hash
        @html_tag ||= 'div'
        @html_tag_params.merge!(id_hash)
      end
      
      [res, drag_handle]
    end
    
    def expand_with(acontext={})
      # set variables
      context = nil
      pre = ''
      @blocks.each do |block|
        next if block.kind_of?(String) || block.method != 'set'
        @context[:vars] ||= []
        context ||= @context.merge(acontext).merge(:set => true)
        pre << expand_block(block, context)
        @context[:vars] << block.params[:var]
      end
      
      pre + super
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
        elsif ref_date =~ /(\d{4}-\d{1,2}-\d{1,2}( \d{1,2}:\d{1,2}(:\d{1,2})?)?)/
          ref_date = "'#{$1}'"
        elsif ref_date =~ /\A"/
          ref_date = "'\#{format_date(#{ref_date})}'"
        else
          ref_date = "'\#{#{ref_date}.strftime('%Y-%m-%d %H:%M:%S')}'"
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
          "#{field} >= #{ref_date}"
        else
          # date_add('2008-01-31 23:50',INTERVAL 1 hour)
          if date_cond =~ /^(\+|-|)\s*(\d+)\s*(second|minute|hour|day|week|month|year)/
            count = $2.to_i
            if $1 == ''
              # +/-
              "#{field} > #{ref_date} - INTERVAL #{count} #{$3.upcase} AND #{field} < #{ref_date} + INTERVAL #{count} #{$3.upcase}"
            elsif $1 == '+'
              # x upcoming days
              "#{field} > #{ref_date} AND #{field} < #{ref_date} + INTERVAL #{count} #{$3.upcase}"
            else
              # x days in the past
              "#{field} < #{ref_date} AND #{field} > #{ref_date} - INTERVAL #{count} #{$3.upcase}"
            end
          end
        end
      end
    end
  end
end

if defined?(RAILS_ENV)
  load_zafu_rules_from_bricks
end