module Bricks
  module Activity
    module ControllerMethods
      def self.included(base)
        base.class_eval do
          alias_method_chain :set_visitor, :activity
        end
      end

      def set_visitor_with_activity
        set_visitor_without_activity
        Zena::Db.set_attribute(visitor, 'seen_at', Time.now.utc)
      end
    end # ControllerMethods

    module UserMethods
      def self.included(base)
        base.class_eval do
          safe_method :seen_at => Time
        end
      end
    end # UserMethods
  end
end
