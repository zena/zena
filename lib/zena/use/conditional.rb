module Zena::Use::Conditional
  module ZafuMethods

    def rubyless_class_scope(class_name)
      # capital letter ==> class conditional
      klass = Node.get_class(class_name)
      if klass.kpath =~ %r{^#{node.klass.kpath}}
        out expand_if("#{node}.kpath_match?('#{klass.kpath}')", node.move_to(node.name, klass))
      else
        # render nothing: incompatible classes
        ''
      end
    #rescue NameError
    #  parser_error("Invalid class name '#{class_name}'")
    end
  end
end # Zena::Use::ZafuClass
