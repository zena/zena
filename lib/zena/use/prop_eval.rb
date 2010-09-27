module Zena
  module Use
    module PropEval
      module VirtualClassMethods
        def self.included(base)
          base.validate :validate_prop_eval
        end

        private
          def validate_prop_eval
            # Create a temporary class and load roles
            klass = Zena::Acts::Enrollable.make_class(self)

            code = self[:prop_eval]
            if code.blank?
              self[:prop_eval] = nil
              return
            end

            begin
              ruby = RubyLess.translate(klass, code)
              klass = ruby.klass

              if !klass.kind_of?(Hash)
                errors.add(:prop_eval, _('Compilation should produce a Hash (Found %s).') % klass)
              end
            rescue RubyLess::Error => err
              errors.add(:prop_eval, err.message)
            end
          end
      end # VirtualClassMethods

      module ModelMethods

        def self.included(base)
          base.before_validation  :merge_prop_eval
        end

        def merge_prop_eval
          return unless self[:vclass_id]
          if code = vclass[:prop_eval]
            hash = safe_eval(code)
            if hash.kind_of?(Hash)
              # forces a check on valid properties
              self.attributes = hash
              true
            else
              errors.add(:base, "Invalid computed properties result (expected a Hash, found #{hash.class}).")
              false
            end
          end
        rescue RubyLess::Error => err
          errors.add(:base, "Error during evaluation of #{klass} computed properties (#{err.message}).")
          return false # Will this properly halt the save chain ?
        end
      end # ModelMethods
    end # PropEval
  end # Use
end # Zena