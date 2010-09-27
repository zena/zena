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
                ruby = RubyLess.translate(klass, code)

                klass = ruby.klass

                unless klass.kind_of?(Class) && klass <= String
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
          base.alias_method_chain :rebuild_index!, :fulltext
        end

        def rebuild_index_with_fulltext!
          visible_versions.each do |version|
            build_fulltext_indices(version)
            fields_to_set = []
            FULLTEXT_FIELDS.each do |idx_group|
              next unless version.changes[idx_group]
              fields_to_set << "#{idx_group}=#{Zena::Db.quote(version[idx_group])}"
            end

            unless fields_to_set.empty?
              Version.connection.execute "UPDATE versions SET #{fields_to_set.join(',')} WHERE id=#{version.id}"
            end
          end
          rebuild_index_without_fulltext!
        end

        private
          # Prepare roles to add/remove to object.
          def build_fulltext_indices(rebuild_version = nil)
            # Make sure roles are loaded because we compile RubyLess.
            load_roles!

            if rebuild_version
              version = rebuild_version
              # make sure prop corresponds to the correct version content
              @properties = version.prop
            else
              return unless prop.changed?
              version = self.version
            end

            klass = self.virtual_class || {}

            FULLTEXT_FIELDS.each do |idx_group|
              code = klass[idx_group]
              if !code.blank?
                begin
                  version[idx_group] = safe_eval(code)
                rescue RubyLess::Error => err
                  errors.add('base', "Error while building '#{idx_group}' index: #{err.message}")
                end
              else
                version[idx_group] = prop[DEFAULT_INDEX[idx_group]]
              end
            end
          end
      end # ModelMethods
    end # Fulltext
  end # Use
end # Zena