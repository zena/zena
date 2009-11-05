module Zafu
  module Meta

    def r_debug
      return '' unless @context[:dev]
      add_html_class('debug')
      out "<p>#{@params[:title] || @params[:message]}</p>" if @params[:title] || @params[:message]
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

    def parser_error(message, tag=@method)
      "<span class='parser_error'>[#{tag}] #{message}</span>"
    end
  end
end
