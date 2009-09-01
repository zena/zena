module Zena
  module Use
    module I18n
      module Common
      end # Common

      module ControllerMethods
        include Common        
      end
      
      module ViewMethods
        include Common
      end
      
    end # I18n
  end # Use
end # Zena