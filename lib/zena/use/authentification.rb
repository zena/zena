module Zena
  module Use
    module Authentification
      module Common
      end # Common

      module ControllerMethods
        include Common        
      end
      
      module ViewMethods
        include Common
      end
      
    end # Authentification
  end # Use
end # Zena