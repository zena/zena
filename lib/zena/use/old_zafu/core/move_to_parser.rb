# Elements here should be moved to the core zafu parser
module Zafu
  module Core
    module MoveToParser
      def before_render
        return unless super

        @var = nil # reset var counter

        if key = @params[:store]
          set_stored(Node, key, node)
        end

        if key = @params[:store_date]
          set_stored(Date, key, current_date)
        end
        if @method != 'link'
          @anchor_param = @params[:anchor]
        end

        true
      end


      def after_render(text)
        if @anchor_param
          @params[:anchor] = @anchor_param # set back in case of double rendering so it is computed again
          r_anchor + super
        else
          super
        end
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
            if node.will_be?(DataEntry) && @method.to_s =~ /node_/
              # select node_id
              "<%= select_id('#{base_class.to_s.underscore}', '#{@method}_id') %>"
            end
          end
          res =  "<#{@html_tag || 'div'} class='zazen'>#{res}</#{@html_tag || 'div'}>" if [:r_summary, :r_text].include?(sym)
        end


        res ||= super(method)
        "#{pre}#{res}#{post}"
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

      def context
        return @context if @context
        # not rendered yet, find first parent with context
        @context = parent ? parent.context : {}
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
    end # MoveToParser
  end # Core
end # Zafu