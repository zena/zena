module Zena
  module Use
    module Ajax
      module Common
      end # Common

      module ControllerMethods
        include Common        
      end
      
      module ViewMethods
        include Common
      end
      
    end # Ajax
  end # Use
end # Zena