module Bricks
  module Single
    module SiteMethods
      def self.included(base)
        base.class_eval do
          alias_method_chain :public_path, :single
        end
      end

      def public_path_with_single
        "/../public"
      end
    end # SiteMethods
  end # Single
end # Bricks