module Zena::Use::Conditional
  module ZafuMethods

    def rubyless_class_scope(class_name)
      # capital letter ==> class conditional
      if klass = get_class(class_name)
        if klass.kpath =~ %r{^#{node.klass.kpath}} || @context[:saved_template]
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
        if node.klass.kpath =~ %r{^#{role.kpath}} || @context[:saved_template]
          # Saved templates can be rendered with anything...
          # FIXME: Make sure saved templates from 'block' start with the proper node type ?
          cond     = "#{node}.has_role?(#{role.id})"
          new_node = node.move_to(node.name, klass)
        else
          # render nothing: incompatible classes
          cond     = 'false'
          new_node = node.move_to(node.name, klass)
        end
      else
        return parser_error("Invalid role or class '#{class_name}'")
      end

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
