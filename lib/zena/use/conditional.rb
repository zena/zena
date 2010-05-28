module Zena::Use::Conditional
  module ZafuMethods

    def rubyless_class_scope(class_name)
      # capital letter ==> class conditional
      if klass = get_class(class_name)
        if klass.kpath =~ %r{^#{node.klass.kpath}}
          out expand_if("#{node}.kpath_match?('#{klass.kpath}')", node.move_to(node.name, klass))
        else
          # render nothing: incompatible classes
          out expand_if('false', node.move_to(node.name, klass))
        end
      elsif role = Role.first(:conditions => ['name = ? AND site_id = ?', class_name, current_site.id])
        if node.klass.kpath =~ %r{^#{role.kpath}}
          out expand_if("#{node}.has_role?(#{role.id})", node.move_to(node.name, klass))
        else
          # render nothing: incompatible classes
          out expand_if('false', node.move_to(node.name, klass))
        end
      else
        parser_error("Invalid role or class '#{class_name}'")
      end
    end
  end
end # Zena::Use::ZafuClass
