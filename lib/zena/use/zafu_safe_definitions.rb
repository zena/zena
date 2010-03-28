module Zena
  module Use
    module ZafuSafeDefinitions
      class ParamsDictionary
        include RubyLess
        safe_method ['[]', Symbol] => {:class => String, :nil => true}
      end

      module ViewMethods
        include RubyLess
        safe_method [:params] => ParamsDictionary
        safe_method_for String, [:gsub, Regexp, String] => {:class => String, :pre_processor => true}
        safe_method_for String, :upcase => {:class => String, :pre_processor => true}
        safe_method :visitor => User
        safe_method :site => {:class => Site, :method => 'visitor.site'}
      end
    end
  end
end