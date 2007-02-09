module Zafu
  module Rules
    
    def show
      return unless check_params(:attr)
      attribute = params[:attr]
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
    
    def parent
      out "<% if #{var} = #{node}.parent -%>"
      out expand_with(:node=>var)
      out "<% end -%>"
    end
  end
end