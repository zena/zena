module Zafu
  module Eval

    def r_set
      return parser_error("'var' missing") unless var_name = @params[:var]
      return parser_error("bad value for 'var' (#{var_name.inspect})") unless var_name =~ /^[a-zA-Z_]+$/
      return '' unless @context[:set]
      if @params[:value]
        out "<% set_#{var_name} = #{@params[:value].inspect} -%>"
        # TODO: isn't @context[:vars] = @params[:value].inspect missing here ?
      elsif @params[:eval]
        return unless eval_string = parse_eval_parameter(@params[:eval])
        out "<% set_#{var_name} = #{eval_string} -%>"
      else
        out "<% set_#{var_name} = capture do %>"
        out expand_with(:set => false) # do not propagate
        out "<% end -%>"
      end
    end

    def parse_eval_parameter(str)
      # evaluate an expression. Can only contain vars, '(', ')', '*', '+', '/', '-', '[attr]'
      # FIXME: SECURITY (audit this)
      vars = @context[:vars] || []
      parts = str.split(/\s+/)
      res  = []
      test = []
      parts.each do |p|
        if p =~ /\[([\w_]+)\]/
          test << 1
          res << (node_attribute($1) + '.to_f')
        elsif p =~ /^[a-zA-Z_]+$/
          unless vars.include?(p)
            out parser_error("var #{p.inspect} not set in eval")
            return nil
          end
          test << 1
          res  << "set_#{p}.to_f"
        elsif ['(', ')', '*', '+', '/', '-'].include?(p)
          res  << p
          test << p
        elsif p =~ /^[0-9\.]+$/
          res  << p
          test << p
        else
          out parser_error("bad argument #{p.inspect} in eval")
          return nil
        end
      end
      begin
        begin
          eval test.join(' ')
        rescue
          # rescue evaluation error
          out parser_error("error in eval")
          return nil
        end
        "(#{res.join(' ')})"
      rescue SyntaxError => err
        # rescue compilation error
        out parser_error("compilation error in eval")
        return nil
      end
    end
  end # Eval
end # Zafu