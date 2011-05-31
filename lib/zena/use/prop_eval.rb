module Zena
  module Use
    module PropEval
      module VirtualClassMethods
        def self.included(base)
          base.class_eval do
            validate :validate_prop_eval
            attr_accessible :prop_eval
            property do |p|
              p.string 'prop_eval'
            end
            self.export_attributes += %w{prop_eval}
          end
        end

        private
          def validate_prop_eval
            # Make sure the class is fully loaded
            load_attached_roles!

            code = self.prop_eval
            if code.blank?
              self.prop_eval = nil
              return
            end
            
            begin
              ruby = RubyLess.translate(self, code)
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
          base.before_validation  :need_set__id
          base.before_save        :set__id
          base.alias_method_chain :rebuild_index_for_version, :prop_eval
          # So that we can use 'now' with prop_eval
          base.safe_method :now => {:class => Time, :method => 'Time.now'}
        end

        def rebuild_index_for_version_with_prop_eval(version)
          # Call other modules inserted before
          rebuild_index_for_version_without_prop_eval(version)
          merge_prop_eval(true)
          # Only save properties, without changing updated_at date or other callbacks
          Zena::Db.set_attribute(version, 'properties', encode_properties(@properties)) if version.changed?
        end

        def need_set__id
          # Set DB identifier _id with latest title
          # This is not the best place to put this code, but it's hard to make sure it is only executed
          # in the correct order (after all properties are evaluated).

          @need_set__id = prop.title_changed?
          true
        end

        # TODO: decide if we need to keep this (Zena::Remote makes a much better console the MySQL console...)
        def set__id
          self._id = self.title if @need_set__id
        end

        # Must happend after 'change_klass'
        def merge_prop_eval(force_rebuild = false)
          return unless vclass_id
          return unless force_rebuild || prop.changed? || klass_changed?

          if code = vclass.prop_eval
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