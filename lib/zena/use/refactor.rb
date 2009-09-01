module Zena
  module Use
    module Refactor
      module Common
      end # Common

      module ControllerMethods
        include Common        
      end
      
      module ViewMethods
        include Common
      end
      
    end # Refactor
  end # Use
end # Zena