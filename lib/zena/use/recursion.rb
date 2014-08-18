module Zena
  module Use
    module Recursion
      module ZafuMethods
        def self.included(base)
          base.before_process :recursion_prepare
          base.after_process  :recursion_call
        end

        # recursion
        def r_include
          return '' if @context[:saved_template]
          return parser_error("missing 'template' or 'part' parameter") if !@params[:part]
          recursion = get_context_var('recursion', @params[:part])
          return parser_error("no parent named '#{@params[:part]}'") unless recursion
          klass = recursion[:klass]
          if klass.kind_of?(Array)
            return parser_error("node context '#{node.klass}' incompatible with '[#{klass}]'")   unless node.list_context?
            return parser_error("node context '[#{node.klass}]' incompatible with '[#{klass}]'") unless node.klass.first <= klass.first
          else
            return parser_error("node context '[#{node.klass}]' incompatible with '#{klass}'") if node.list_context?
            return parser_error("node context '#{node.klass}' incompatible with '#{klass}'") unless node.klass <= klass
          end
          depth = get_context_var('recursion', 'depth')
          "<% #{recursion[:proc_name]}.call(#{depth}+1,#{node}) %>"
        end

        private
          def recursion_prepare
            inc = descendant('include')
            if inc && inc.params[:part] == @name
              # We are called by a descendant, create method
              proc_name = unique_name.gsub(/[^\w]/,'_')

              if node.klass.kind_of?(Array)
                if node.klass.first.name.blank?
                  # Skip current anonymous class
                  klass = [node.klass.first.superclass]
                else
                  klass = node.klass
                end
              else
                if node.klass.name.blank?
                  # Skip current anonymous class
                  klass = node.klass.superclass
                else
                  klass = node.klass
                end
              end

              set_context_var('recursion', @name, {:proc_name => proc_name, :klass => klass})
              depth = get_var_name('recursion', 'depth')
              out "<% #{proc_name} = Proc.new do |#{depth}, #{var}| %>"
              out "<% next if #{depth} > #{inc.params[:depth] ? [inc.params[:depth].to_i,30].min : 5} %>"
              @recursion_call =  "<% end %><% #{proc_name}.call(0,#{node}) %>"
              @context[:node] = node.move_to(var, node.klass)
              @var = nil # avoid reuse of our 'var' as new var name
            end
          end

          def recursion_call(res)
            if @recursion_call
              res = res + @recursion_call
              @recursion_call = nil
            end
            res
          end
      end # ZafuMethods
    end # Recursion
  end # Use
end # Zena