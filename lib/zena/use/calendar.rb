module Zena
  module Use
    module Calendar
      module Common
      end # Common

      module ControllerMethods
        include Common        
      end
      
      module ViewMethods
        include Common
      end
      
    end # Calendar
  end # Use
end # Zena