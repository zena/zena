module Zena
  module Use
    # This module hides 'has_many' versions as if there was only a 'belongs_to' version,
    # automatically registering the latest version's id.
    module MultiVersion
      # This module should be included in the model that serves as version.
      module Version
        def self.included(base)

          base.class_eval do
            attr_accessor :__destroy
            belongs_to :node
            before_create :setup_version_on_create
            attr_protected :number, :user_id

            alias_method_chain :node, :secure
            alias_method_chain :save, :destroy
          end
        end

        def node_with_secure
          @node ||= begin
            if n = node_without_secure
              visitor.visit(n)
              n.version = self
            end
            n
          end
        end

        def save_with_destroy(*args)
          if @__destroy
            node = self.node
            if destroy
              # reset @version
              node.send(:version_destroyed)
              true
            end
          else
            save_without_destroy(*args)
          end
        end

        private
          def setup_version_on_create
            raise "You should define 'setup_version_on_create' method in '#{self.class}' class."
          end
      end

      def self.included(base)
        base.has_many      :versions, :order=>"number DESC", :dependent => :destroy  #, :inverse_of => :node
        base.validate      :validate_version
        base.before_update :save_version_before_update
        base.after_create  :save_version_after_create
        #base.accepts_nested_attributes_for :version

        base.alias_method_chain :save, :destroy
      end

      def save_with_destroy(*args)
        version = self.version
        # TODO: we could use 'version.mark_for_destruction' instead of __destroy...
        if version.__destroy && versions.count == 1
          self.destroy # will destroy last version
        else
          self.save_without_destroy(*args)
        end
      end

      def version_attributes=(attributes)
        version.attributes = attributes
      end

      # The logic to get the 'current' version should be
      # rewritten in class including MultiVersion.
      def version
        raise "You should define 'version' method in '#{self.class}' class."
      end

      def version=(v)
        @version = v
      end

      private

        def validate_version
          # We force the existence of at least one version with this code
          unless version.valid?
            merge_version_errors
          end
        end

        def save_version_before_update
          if !@version.save #_with_validation(false)
            merge_version_errors
          else
            current_version_before_update
          end
        end

        def save_version_after_create
          version.node_id = self[:id]
          if !@version.save #_with_validation(false)
            merge_version_errors
            rollback!
          else
            current_version_after_create
          end
          true
        end

        # This method is triggered when the version is saved, but before the
        # master record is updated.
        # The role of this method is typically to do things like:
        #   self[:version_id] = version.id
        def current_version_before_update
        end

        # This method is triggered when the version is saved, after the
        # master record has been created.
        # The role of this method is typically to do things like:
        #   update_attribute(:version_id, version.id)
        def current_version_after_create
        end

        # This is called after a version is destroyed
        def version_destroyed
          # remove from versions list
          if versions.loaded?
            node.versions -= [@version]
          end
        end

        def merge_version_errors
          @version.errors.each_error do |attribute, message|
            attribute = "version_#{attribute}"
            errors.add(attribute, message) unless errors[attribute] # FIXME: rails 3: if errors[attribute].empty?
          end
        end
    end
  end
end