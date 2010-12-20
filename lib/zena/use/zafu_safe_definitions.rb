module Zena
  module Use
    module ZafuSafeDefinitions
      class ParamsDictionary
        include RubyLess
        safe_method ['[]', Symbol] => {:class => String, :nil => true}
      end

      module ViewMethods
        include RubyLess

        # Dynamic resolution of kind_of
        def self.kind_of_proc
          Proc.new do |receiver, role_or_vclass|
            if role_or_vclass.kind_of?(VirtualClass)
              res = "#{receiver}.kpath_match?('#{role_or_vclass.kpath}')"
            else
              # Role
              res = "#{receiver}.has_role?(#{role_or_vclass.id})"
            end

            RubyLess::TypedString.new(res, :class => Boolean)
          end
        end

        safe_method :params => ParamsDictionary
        safe_method :now    => {:method => 'Time.now', :class => Time}
        safe_method [:h, String] => {:class => String, :nil => true}
        safe_method_for String, [:gsub, Regexp, String] => {:class => String, :pre_processor => true}
        safe_method_for String, :upcase    => {:class => String, :pre_processor => true}
        safe_method_for String, :strip     => {:class => String, :pre_processor => true}
        safe_method_for String, :urlencode => {:class => String, :pre_processor => true, :method => :url_name}
        safe_method_for String, :to_i      => {:class => Number, :pre_processor => true}
        safe_method_for Number, :to_s      => {:class => String, :pre_processor => true}
        safe_method_for Object, :blank?    => Boolean

        safe_method_for Node,  [:kind_of?, VirtualClass] =>
        {:method => 'nil', :nil => true, :pre_processor => kind_of_proc}
        safe_method_for Node,  [:kind_of?, Role]   =>
        {:method => 'nil', :nil => true, :pre_processor => kind_of_proc}
        safe_method_for Node,  [:kind_of?, String] => {:method => 'kpath_match?', :class => Boolean}
        safe_method_for Node,  [:kind_of?, Number] => {:method => 'has_role?',    :class => Boolean}
        safe_method_for Array, [:index, String]   => {:class => Number, :nil => true}

      end # ViewMethods


      module ZafuMethods
        def safe_const_type(class_name)
          if klass = VirtualClass[class_name]
            {:method => "VirtualClass[#{class_name.inspect}]", :nil => true, :class => VirtualClass, :literal => klass}
          elsif role = Node.get_role(class_name)
            {:method => "Role.find(#{role.id})", :nil => true, :class => Role, :literal => role}
          else
            nil
          end
        end
      end # ZafuMethods
    end
  end
end