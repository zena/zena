module Zena
  module Parser
    module ZenaRules
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
    end # ZenaRules
  end # Parser
end # Zena