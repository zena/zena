module ParserTags
  module Zafu
    def r_show
      return unless check_params(:attr)
      attribute = @params[:attr]
      attribute = attribute[1..-1] if attribute[0..0] == ':'
      case attribute[0..1]
      when 'v_'
        "<%= #{node}.send(:version)[:#{attribute[2..-1]}] %>"
      when 'c_'
        "<%= #{node}.send(:version).content[:#{attribute[2..-1]}] %>"
      else
        "<%= #{node}[:#{attribute}] %>"
      end
    end

    def r_parent
      out "<% if #{var} = #{node}.parent -%>"
      out expand_with(:node=>var)
      out "<% end -%>"
    end
    
    # find the current node name in the context
    def node
      @context[:node] || '@node'
    end
    
    def list
      @context[:list]
    end
    # <z:relation role='hot,project'> = get relation if empty get project
    # relation ? get ? role ? go ?
  end
end
