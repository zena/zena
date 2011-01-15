module Zena
  module Use
    class NodeContext < Zafu::NodeContext
      def node_klass?
        single_class.kind_of?(VirtualClass)
      end

      def real_single_class
        @real_single_class ||= if node_klass?
          single_class.real_class
        else
          single_class
        end
      end

      def real_class
        @real_class ||= if node_klass?
          klass.kind_of?(Array) ? [klass.first.real_class] : klass.real_class
        else
          klass
        end
      end

      # Return true if the NodeContext represents an element of the given type. We use 'will_be' because
      # it is equivalent to 'is_a', but for future objects (during rendering).
      def will_be?(type)
        if node_klass?
          real_single_class <= type
        else
          super
        end
      end
      
      # Get an uppers NodeContext that is of the given class kind.
      def get(klass)
        if real_single_class <= klass
          return self unless list_context?

          res_class = self.klass
          method = self.name
          while res_class.kind_of?(Array)
            method = "#{method}.first"
            res_class = res_class.first
          end
          move_to(method, res_class)
        elsif @up
          @up.get(klass)
        else
          nil
        end
      end
      
      # Return the 'real' class name or the superclass name if the current class is an anonymous class.
      def class_name
        if list_context?
          "[#{real_single_class}]"
        else
          real_single_class.name
        end
      end
    end
  end # Use
end # Zena