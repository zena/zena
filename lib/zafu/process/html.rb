module Zafu
  module Process
    module HTML
      def self.included(base)
        base.wrap  :wrap_html
      end

      # Replace the 'original' element in the included template with our new version.
      def replace_with(new_obj)
        super
        # [self = original_element]. Replace @markup with content of the new_obj (<ul do='with'>...)
        if new_obj.markup.tag
          @markup.tag = new_obj.markup.tag
        else
          # Steal 'class' param
          @markup.steal_html_params_from(new_obj.params)
        end

        @markup.params.merge!(new_obj.markup.params)

        # We do not have to merge dyn_params since these are compiled before processing (and we are in
        # the pre-processor)

        if new_obj.params[:method]
          @method   = new_obj.params[:method]
        elsif new_obj.sub_do
          @method = 'void'
        end
      end

      # Pass the caller's 'markup' to the included part.
      def include_part(obj)
        if @markup.tag
          obj.markup = @markup.dup
        end
        @markup.tag = nil

        if sub_do
          obj.method = @blocks.first.method
          obj.params = @blocks.first.params
        elsif params[:method]
          obj.method = params[:method]
        end
        super(obj)
      end

      def empty?
        super && @markup.params == {} && @markup.tag.nil?
      end

      def compile_html_params
        return if @markup.done
        unless @markup.tag
          if @markup.tag = @params.delete(:tag)
            @markup.steal_html_params_from(@params)
          end
        end

        # Translate dynamic params such as <tt>class='#{visitor.lang}'</tt> in the context
        # of the current parser
        @markup.compile_params(self)
      end

      def wrap_html(text)
        compile_html_params
        @markup.wrap(text)
      end

      #def restore_markup
      #  # restore @markup
      #  @markup = @markup_bak
      #end

      def inspect
        @markup.done = false
        res = super
        if @markup.tag
          if res =~ /\A\[(\w+)(.*)\/\]\Z/m
            res = "[#{$1}#{$2}]<#{@markup.tag}/>[/#{$1}]"
          elsif res =~ /\A\[([^\]]+)\](.*)\[\/(\w+)\]\Z/m
            res = "[#{$1}]#{@markup.wrap($2)}[/#{$3}]"
          end
        end
        res
      end

      def r_ignore
        @markup.done = true
        ''
      end

      def r_rename_asset
        return expand_with unless @markup.tag
        case @markup.tag
        when 'link'
          key = :href
          return parser_error("Missing 'rel' parameter.") unless rel = @params[:rel]
          return parser_error("Missing 'href' parameter.") unless @params[:href]
          if rel.downcase == 'stylesheet'
            type = :stylesheet
          else
            type = :link
          end
        when 'style'
          @markup.done = true
          return expand_with.gsub(/url\(('|")(.*?)\1\)/) do
            if $2[0..6] == 'http://'
              $&
            else
              quote   = $1
              new_src = helper.send(:template_url_for_asset, :base_path=>@options[:base_path], :src => $2)
              "url(#{quote}#{new_src}#{quote})"
            end
          end
        else
          key = :src
          type = @markup.tag.to_sym
        end

        src = @params.delete(key)
        if src && src[0..7] != 'http://'
          new_value = helper.send(:template_url_for_asset, :src => src, :base_path => @options[:base_path], :type => type)
          @markup.params[key] = new_value.blank? ? src : new_value
        end

        @markup.steal_html_params_from(@params)

        expand_with
      end

      def steal_and_eval_html_params_for(markup, params)
        markup.steal_keys.each do |key|
          next unless value = params.delete(key)
          append_markup_attr(markup, key, value)
        end
      end
      #def r_form
      #  res   = "<#{@markup.tag}#{params_to_html(@params)}"
      #  @markup.done = true
      #  inner = expand_with
      #  if inner == ''
      #    res + "/>"
      #  else
      #    res + ">#{inner}"
      #  end
      #end
      #
      #def r_select
      #  res   = "<#{@markup.tag}#{params_to_html(@params)}"
      #  @markup.done = true
      #  inner = expand_with
      #  if inner == ''
      #    res + "></#{@markup.tag}>"
      #  else
      #    res + ">#{inner}"
      #  end
      #end
      #
      #def r_input
      #  res   = "<#{@markup.tag}#{params_to_html(@params)}"
      #  @markup.done = true
      #  inner = expand_with
      #  if inner == ''
      #    res + "/>"
      #  else
      #    res + ">#{inner}"
      #  end
      #end
      #
      #def r_textarea
      #  res   = "<#{@markup.tag}#{params_to_html(@params)}"
      #  @markup.done = true
      #  inner = expand_with
      #  if inner == ''
      #    res + "/>"
      #  else
      #    res + ">#{inner}"
      #  end
      #end
    end # HTML
  end # Process
end # Zafu