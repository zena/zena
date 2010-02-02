module Zena
  module Use
    # When you include this module into a class, it will automatically clone itself
    # depending on the call to should_clone?
    module AutoVersion
      attr_reader :previous_id

      def self.included(base)
        base.before_save :prepare_save_or_clone
      end

      def should_clone?
        raise Exception.new("You should implement 'should_clone?' in your model (return true for a new version, false to update).")
      end

      # This method provides a hook to alter values after a clone operation (just before save: no validation).
      def cloned
      end

      # Return true if the record was cloned just before the last save
      def cloned?
        !@previous_id.nil?
      end

      def prepare_save_or_clone
        if !new_record? && should_clone?
          @previous_id = self[:id]
          self[:id] = nil
          self[:created_at] = nil
          self[:updated_at] = nil
          @new_record = true
          cloned
        else
          @previous_id = nil
        end
        true
      end
    end
  end
end