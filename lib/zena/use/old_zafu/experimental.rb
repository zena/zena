module Zafu
  module Experimental

    # part caching
    def r_cache
      kpath   = @params[:kpath]   || Page.kpath
      out "<% #{cache} = Cache.with(visitor.id, visitor.group_ids, #{kpath.inspect}, #{helper.send(:lang).inspect}, #{template_url.inspect}) do capture do %>"
      out expand_with
      out "<% end; end %><%= #{cache} %>"
    end

    def cache
      return @cache if @cache
      if @context[:cache] =~ /^cache(\d+)$/
        @cache = "cache#{$1.to_i + 1}"
      else
        @cache = "cache1"
      end
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

    def r_inspect
      out ["params: #{@params.inspect}",
      "name:   #{@context[:name]}",
      "node:   #{node}",
      "list:   #{list}"].join("<br/>")
    end

  end # Experimental
end # Zafu
