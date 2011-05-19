# This should be removed (it is used by zazen but I do not know why)
module Zena
  module Parser
    module ZafuTags
      attr_accessor :html_tag, :html_tag_params, :name, :sub_do

      # Replace the 'original' element in the included template with our new version.
      def replace_with(new_obj)
        super
        html_tag_params    = new_obj.html_tag_params
        [:class, :id].each do |sym|
          html_tag_params[sym] = new_obj.params[sym] if new_obj.params.include?(sym)
        end
        @html_tag = new_obj.html_tag || @html_tag
        @html_tag_params.merge!(html_tag_params)
        if new_obj.params[:method]
          @method   = new_obj.params[:method] if new_obj.params[:method]
        elsif new_obj.sub_do
          @method = 'void'
        end
      end

      # Pass the caller's 'html_tag' and 'html_tag_params' to the included part.
      def include_part(obj)
        obj.html_tag = @html_tag || obj.html_tag
        obj.html_tag_params = !@html_tag_params.empty? ? @html_tag_params : obj.html_tag_params
        @html_tag = nil
        @html_tag_params = {}
        super(obj)
      end

      def empty?
        super && @html_tag_params == {} && @html_tag.nil?
      end

      def before_render
        return unless super
        @html_tag_done = false
        unless @html_tag
          if @html_tag = @params.delete(:tag)
            @html_tag_params = {}
            [:id, :class].each do |k|
              next unless @params[k]
              @html_tag_params[k] = @params.delete(k)
            end
          end
        end
        # [each] is run many times with different roles. Some of these change html_tag_params.
        @html_tag_params_bak = @html_tag_params.dup
        true
      end

      def after_render(text)
        res = render_html_tag(super)
        @html_tag_params = @html_tag_params_bak
        res
      end

      def inspect
        @html_tag_done = false
        res = super
        if @html_tag
          if res =~ /\A\[(\w+)(.*)\/\]\Z/m
            res = "[#{$1}#{$2}]<#{@html_tag}/>[/#{$1}]"
          elsif res =~ /\A\[([^\]]+)\](.*)\[\/(\w+)\]\Z/m
            res = "[#{$1}]#{render_html_tag($2)}[/#{$3}]"
          end
        end
        res
      end

      def params_to_html(params)
        para = []
        params.each do |k,v|
          if v.kind_of?(Array)
            # Array is used to indicate that the code is already escaped.
            para << " #{k}=#{v}"
          elsif !v.to_s.include?("'")
            para << " #{k}='#{v}'"
          else
            para << " #{k}=\"#{v.to_s.gsub('"','\"')}\"" # TODO: do this work in all cases ?
          end
        end
        # puts para.inspect
        para.sort.join('')
      end

      def render_html_tag(text,*append)
        append ||= []
        return text if @html_tag_done
        if @html_tag
          if text.blank? && ['meta','input'].include?(@html_tag)
            res = "<#{@html_tag}#{params_to_html(@html_tag_params || {})}#{append.join('')}/>"
          else
            res = "<#{@html_tag}#{params_to_html(@html_tag_params || {})}#{append.join('')}>#{text}</#{@html_tag}>"
          end
        else
          res = text
        end
        @html_tag_done = true
        return res if @context && @context[:only] && !@context[:only].include?(:string)
        (@space_before || '') + res + (@space_after || '')
      end

      def r_ignore
        @html_tag_done = true
        ''
      end

      alias r_ r_ignore

      def r_rename_asset
        return expand_with unless @html_tag
        case @html_tag
        when 'link'
          key = :href
          if @params[:rel].downcase == 'stylesheet'
            type = :stylesheet
          else
            type = :link
          end
        when 'style'
          @html_tag_done = true
          return expand_with.gsub(/url\(('|")(.*?)\1\)/) do
            if $2[0..6] == 'http://'
              $&
            else
              quote   = $1
              new_src = @options[:helper].send(:template_url_for_asset, :base_path => @options[:base_path], :src => $2)
              "url(#{quote}#{new_src}#{quote})"
            end
          end
        else
          key = :src
          type = @html_tag.to_sym
        end

        src = @params[key]
        if src && src[0..0] != '/' && src[0..6] != 'http://'
          @params[key] = @options[:helper].send(:template_url_for_asset, :src => src, :base_path => @options[:base_path], :type => type)
        end

        res   = "<#{@html_tag}#{params_to_html(@params)}"
        @html_tag_done = true
        inner = expand_with
        if inner == ''
          res + "/>"
        else
          res + ">#{inner}"
        end
      end

      def r_form
        res   = "<#{@html_tag}#{params_to_html(@params)}"
        @html_tag_done = true
        inner = expand_with
        if inner == ''
          res + "/>"
        else
          res + ">#{inner}"
        end
      end

      def r_select
        res   = "<#{@html_tag}#{params_to_html(@params)}"
        @html_tag_done = true
        inner = expand_with
        if inner == ''
          res + "></#{@html_tag}>"
        else
          res + ">#{inner}"
        end
      end

      def r_input
        res   = "<#{@html_tag}#{params_to_html(@params)}"
        @html_tag_done = true
        inner = expand_with
        if inner == ''
          res + "/>"
        else
          res + ">#{inner}"
        end
      end

      def r_textarea
        res   = "<#{@html_tag}#{params_to_html(@params)}"
        @html_tag_done = true
        inner = expand_with
        if inner == ''
          res + "/>"
        else
          res + ">#{inner}"
        end
      end
    end # ZafuTags
  end # Parser
end # Zena