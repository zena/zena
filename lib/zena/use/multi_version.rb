module Zena
  module Use
    # This module hides 'has_many' versions as if there was only a 'belongs_to' version,
    # automatically registering the latest version's id.
    module MultiVersion
      # This module should be included in the model that serves as version.
      module Version
        def self.included(base)

          base.class_eval do
            belongs_to :node
            before_validation :set_lang
            before_create :setup_version_on_create
            attr_protected :number, :user_id

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


        private
          # This must be done before validation so that cloning occurs if this value changes
          def set_lang
            self[:lang] = visitor.lang
          end

          def setup_version_on_create
            # set number
            last_record = self[:node_id] ? self.connection.select_one("select number from #{self.class.table_name} where node_id = '#{node[:id]}' ORDER BY number DESC LIMIT 1") : nil
            self[:number] = (last_record || {})['number'].to_i + 1

            # set author
            self[:user_id] = visitor.id
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

        def merge_version_errors
          @version.errors.each_error do |attribute, message|
            attribute = "version_#{attribute}"
            errors.add(attribute, message) unless errors[attribute] # FIXME: rails 3: if errors[attribute].empty?
          end
        end
    end
  end
end