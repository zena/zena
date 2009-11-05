module Zafu
  module I18n
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

    def _(text)
      if @context[:dict]
        @context[:dict][text] || helper.send(:_,text)
      else
        helper.send(:_,text)
      end
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
  end # I18n
end # Zafu