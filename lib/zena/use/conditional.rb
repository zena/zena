module Zena::Use::Conditional
  module ZafuMethods

    def rubyless_class_scope(class_name)
      # capital letter ==> class conditional
      klass = get_class(class_name)
      if klass.kpath =~ %r{^#{node.klass.kpath}}
        out expand_if("#{node}.kpath_match?('#{klass.kpath}')", node.move_to(node.name, klass))
      else
        # render nothing: incompatible classes
        ''
      end
    #rescue NameError
    #  parser_error("Invalid class name '#{class_name}'")
    end

    def get_class(class_name)
      if klass = Node.get_class(class_name)
        Zena::Acts::Enrollable.make_class(klass)
      else
        nil
      end
    end
  end
end # Zena::Use::ZafuClass
