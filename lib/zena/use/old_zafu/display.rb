module Zafu
  module Display

    # This should be done with rubyless... (methods on the compiler...)
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
    direct_methods :uses_datebox

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
        attribute_method = node_class.ancestors.include?(String) ? node : node_attribute('to_s')
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
        actions = "<%= node_actions(:node=>#{node}#{params_to_erb(:actions=>@params[:actions], :publish_after_save=>auto_publish_param)}) %>"
      else
        actions = ''
      end

      attribute = @params[:attr] || @params[:tattr] || @params[:date]

      if (@params[:edit_preview] || @params[:ep]) == 'true'
        @html_tag_params[:id] = "#{attribute}#{erb_node_id}"
        @html_tag ||= 'span'
      end

      if @params[:edit] == 'true' && !['url','path'].include?(attribute)
        "<% if #{node}.can_write? -%><span class='show_edit' id='#{erb_dom_id("_#{attribute}")}'>#{actions}<%= link_to_remote(#{attribute_method}, :url => edit_node_path(#{node_id}) + \"?attribute=#{attribute}&dom_id=#{dom_id("_#{attribute}")}#{auto_publish_param(true)}\", :method => :get) %></span><% else -%>#{actions}<%= #{attribute_method} %><% end -%>"
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
        res = "<% if #{node}.can_write? -%><span class='zazen_edit'><%= link_to_remote(#{edit_text.inspect}, :url => edit_node_path(#{node_id}) + \"?attribute=#{attribute}&dom_id=#{dom_id("_#{attribute}")}#{auto_publish_param(true)}&zazen=true\", :method => :get) %></span><% end -%>#{res}"
      else
        res
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

    def r_title
      # 1. extract / compile options
      # 1.1 extract 'status', node_actions ===> rubyless "title(xxx, xxx) + actions('all')" ==> title helper && node_actions helper
      # 2. render_as_rubyless("title", opts)

      common [
        prefix
        status
        actions...publish
      ]
      <h1 do='title' project='true' check_lang='false'.../>
      <h1 do='prefix(:project, :lang) + title + actions'/>
      <h1 do='title' prefix='project,lang' actions='all' status='true'/>









      if node.will_be?(Version)
        node = "#{self.node}.node"
      elsif node.will_be?(Node)
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
        res << " + node_actions(:node=>#{node}#{params_to_erb(:actions=>@params[:actions], :publish_after_save=>auto_publish_param)})"
      end
      res << "%>"
      if @params[:status] == 'true' || (@params[:status].nil? && @params[:actions])
        @html_tag ||= 'span'
        add_html_class("s<%= #{node}.version.status %>")
      end
      res
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

    # TODO: test
    def r_actions
      out expand_with
      out "<%= node_actions(:node=>#{node}#{params_to_erb(:actions=>@params[:select], :publish_after_save=>auto_publish_param)}) %>"
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

    def r_img
      return unless node.will_be?(Node)
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
        "<a class='zena' href='http://zenadmin.org' title='zena <%= Zena::VERSION %>'>#{text}</a>"
      end
    end

  end # Display
end # Zafu