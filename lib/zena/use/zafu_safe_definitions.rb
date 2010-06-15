module Zena
  module Use
    module ZafuSafeDefinitions
      class ParamsDictionary
        include RubyLess
        safe_method ['[]', Symbol] => {:class => String, :nil => true}
      end

      module ViewMethods
        include RubyLess
        safe_method :params => ParamsDictionary
        safe_method :now    => {:method => 'Time.now', :class => Time}
        safe_method_for String, [:gsub, Regexp, String] => {:class => String, :pre_processor => true}
        safe_method_for String, :upcase => {:class => String, :pre_processor => true}
        safe_method_for Object, :blank? => Boolean

        safe_method_for Node, [:kind_of?, String] => {:method => 'kpath_match?', :class => Boolean}
        safe_method_for Node, [:kind_of?, Number] => {:method => 'has_role?',    :class => Boolean}
      end # ViewMethods


      module ZafuMethods

        def safe_const_type(class_name)
          if klass = get_class(class_name)
            {:method => "'#{klass.kpath}'", :class => String}
          elsif role = Node.get_role(class_name)
            {:method => role.id.to_s, :class => Number}
          else
            nil
          end
        end
      end # ZafuMethods
    end
  end
end