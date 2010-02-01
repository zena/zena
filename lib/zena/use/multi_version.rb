module Zena
  module Use
    # This module hides 'has_many' versions as if there was only a 'belongs_to' version,
    # automatically registering the latest version's id.
    module MultiVersion
      # This module should be included in the model that serves as version.
      module Version
        def self.included(base)
          base.belongs_to :node

          base.class_eval do
            def node_with_secure
              @node ||= begin
                if n = node_without_secure
                  visitor.visit(n)
                  n.version = self
                end
                n
              end
            end
            alias_method_chain :node, :secure
          end
        end

        def set_defaults
          self[:user_id] = visitor.id
          self[:lang]    = visitor.lang
        end
      end

      def self.included(base)
        base.has_many   :versions, :order=>"number DESC", :dependent => :destroy  #, :inverse_of => :node
        base.validate      :validate_version
        base.before_update :save_version_before_update
        base.after_create  :save_version_after_create
        #base.accepts_nested_attributes_for :version
      end

      def version_attributes=(attributes)
        version.attributes = attributes
      end

      def version
        @version ||= begin
          if v_id = version_id
            version = ::Version.find(v_id)
          else
            version = ::Version.new
            version.set_defaults
          end
          version.node = self
          version
        end
      end

      def version=(v)
        @version = v
      end

      private

        def validate_version
          # We force the existence of at least one version with this code
          unless version.valid?
            @version.errors.each_error do |attribute, message|
              attribute = "version_#{attribute}"
              errors.add(attribute, message) unless errors[attribute] # FIXME: rails 3: if errors[attribute].empty?
            end
          end
        end

        def save_version_before_update
          if !@version.save_with_validation(false)
            errors.add('version', 'could not be saved')
          else
            set_current_version(@version)
          end
        end

        def save_version_after_create
          version.node_id = self[:id]
          if !@version.save_with_validation(false)
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