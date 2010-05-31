module Zena
  module Use
    module Fulltext
      FULLTEXT_FIELDS = %w{idx_text_low idx_text_medium idx_text_high}.freeze
      DEFAULT_INDEX   = {'idx_text_high' => 'title', 'idx_text_medium' => 'summary', 'idx_text_low' => 'text'}

      module VirtualClassMethods
        def self.included(base)
          base.validate :validate_fulltext_indices
        end

        private
          def validate_fulltext_indices
            # Create a temporary class and load roles
            klass = Zena::Acts::Enrollable.make_class(self)

            FULLTEXT_FIELDS.each do |idx_group|
              next unless code = self[idx_group]

              begin
                ruby = RubyLess.translate_string(code, klass)

                unless ruby.klass <= String
                  errors.add(idx_group, _('Compilation should produce a String. Found %s.') % ruby.klass.name)
                end
              rescue RubyLess::Error => err
                errors.add(idx_group, err.message)
              end
            end
          end

      end # VirtualClassMethods

      module ModelMethods

        def self.included(base)
          base.before_validation :build_fulltext_indices
        end

        private
          # Prepare roles to add/remove to object.
          def build_fulltext_indices
            return unless prop.changed?
            klass = self.virtual_class || {}

            FULLTEXT_FIELDS.each do |idx_group|
              code = klass[idx_group]
              if !code.blank?
                version[idx_group] = safe_eval_string(code)
              else
                version[idx_group] = prop[DEFAULT_INDEX[idx_group]]
              end
            end
          end
      end # ModelMethods
    end # Fulltext
  end # Use
end # Zena