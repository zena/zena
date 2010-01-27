module Zena
  module Use
    # This module hides 'has_many' versions as if there was only a 'belongs_to' version,
    # automatically registering the latest version's id.
    module MultiVersion
      def self.included(base)
        base.has_many :versions
        base.belongs_to :version
        base.before_update :save_version_before_update
        base.after_create :save_version_after_create
        base.accepts_nested_attributes_for :version
      end

      private
        def save_version_before_update
          if !@version.save
            errors.add('version', 'could not be saved')
          else
            set_current_version(@version)
          end
        end

        def save_version_after_create
          version.node_id = self[:id]
          if !@version.save
            errors.add('version', 'could not be saved')
            rollback!
          else
            update_current_version(@version)
          end
        end

        def set_current_version(version)
          self[:version_id] = version.id
        end

        def update_current_version(version)
          self[:version_id] = version.id
          update_attribute(:version_id, version.id)
        end
    end
  end
end