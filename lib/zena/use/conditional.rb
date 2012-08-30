module Zena::Use::Conditional
  module ZafuMethods

    def r_selenium
      return parser_error("missing 'id'.") if @name.blank?
      out expand_if("params[:test]==#{@name.inspect} || params[:test]=='all'")
    end

    def rubyless_class_scope(class_name)
      return parser_error("Cannot scope class in list (use each before filtering).") if node.list_context?
      # capital letter ==> class conditional
      if klass = VirtualClass[class_name]
        if node.klass.kpath =~ %r{^#{klass.kpath}} || klass.kpath =~ %r{^#{node.klass.kpath}} || @context[:saved_template]
          # Saved templates can be rendered with anything...
          # FIXME: Make sure saved templates from 'block' start with the proper node type ?
          cond     = "#{node}.kpath_match?('#{klass.kpath}')"
          new_node = node.move_to(node.name, klass)
        else
          # render nothing: incompatible classes
          cond     = 'false'
          new_node = node.move_to(node.name, klass)
        end
      elsif role = Node.get_role(class_name)
        if node.klass.kpath =~ %r{^#{role.kpath}} || role.kpath =~ %r{^#{node.klass.kpath}} || @context[:saved_template]
          # Saved templates can be rendered with anything...
          # FIXME: Make sure saved templates from 'block' start with the proper node type ?
          cond     = "#{node}.has_role?(#{role.id})"
          new_node = node.move_to(node.name, node.klass)
        else
          # render nothing: incompatible classes
          cond     = 'false'
          new_node = node.move_to(node.name, node.klass)
        end
      else
        return parser_error("Invalid role or class '#{class_name}'")
      end

      # Class filtering should not block 'saved_dom_id' propagation.
      new_node.saved_dom_id = node.saved_dom_id

      if parent.method == 'case'
        with_context(:node => new_node) do
          r_elsif(cond)
        end
      else
        out expand_if(cond, new_node)
      end
    end
  end
end # Zena::Use::ZafuClass
