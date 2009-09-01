module Zena
  module Use
    module ErrorRendering
      module Common
      end # Common

      module ControllerMethods
        include Common        
      end
      
      module ViewMethods
        include Common
      end
      
    end # ErrorRendering
  end # Use
end # Zena