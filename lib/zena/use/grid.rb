module Zena
  module Use
    module Grid
      module Common
      end # Common

      module ControllerMethods
        include Common        
      end
      
      module ViewMethods
        include Common
      end
      
    end # Grid
  end # Use
end # Zena