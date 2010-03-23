module Zena
  module Use
    module ZafuSafeDefinitions
      class ParamsDictionary
        include RubyLess::SafeClass
        safe_method ['[]', Symbol] => {:class => String, :nil => true}
        disable_safe_read
      end

      module ViewMethods
        include RubyLess::SafeClass
        safe_method [:params] => ParamsDictionary
      end
    end
  end
end