module Zena
  module Refactor
    module Version
      def self.included(base)
        class << base
          def content_class
            nil
          end
        end
      end

    end
  end
end