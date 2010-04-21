module Zena

  # version status
  Status = {
    :red  => 70,
    :prop_with => 65,
    :prop => 60,
    :pub  => 50,
    :rep  => 20,
    :rem  => 10,
    :del  => 0,
  }.freeze

  module Use
    # The workflow module manages the different versions' status and transitions. This module depends on MultiVersion and VersionHash
    # and it should be included *before* these two modules.
    module Workflow
      WORKFLOW_ATTRIBUTES = ['status', 'publish_from']
      # The Workflow::VersionMethods module should be included in the model used as version.
      module VersionMethods
        attr_reader   :stored_workflow, :status_set
        # Enable the use of version.backup = 'true' to force clone
        attr_accessor :backup

        def self.included(base)
          base.before_save :store_workflow_changes
        end

        # Return stored values before save
        def stored_workflow
          @stored_workflow ||= {}
        end

        def status=(status)
          self[:status] = status
          # We need this to know if the status was set, even if the value was the same
          # as the current value (force published state while editing published version).
          @status_set = true
        end

        # Return true if the 'status' value was set.
        def status_set?
          @status_set
        end

        # Return true if the version should clone itself before save
        def should_clone?
          edited? &&
          ( @backup ||
            user_id != visitor.id ||
            status_changed?       ||
            Time.now > created_at + current_site[:redit_time].to_i )
        end

        # Returns true if the version has been edited (not just a status change)
        def edited?
          return true if new_record? || (changes.keys - WORKFLOW_ATTRIBUTES != [])
          return true if node && node.prop.changed?
        end

        private
          # Version owner needs to know if the publication date has changed, after the
          # version has been saved. Workflow needs to know about the lang changed and
          # previous status.
          def store_workflow_changes
            @stored_workflow = {}
            @stored_workflow[:publish_from_changed] = publish_from_changed?
            @stored_workflow[:lang_was]             = lang_was
            @status_set = nil
            true
          end

      end

      module ClassMethods
        # FIXME: should use class inheritable attribute
        @@transitions = []

        def transitions
          @@transitions
          # something like this does not work: @@transitions[self] ||= []
        end

        def add_transition(name, opts, &block)
          v = opts[:from]
          if v.kind_of?(Symbol)
            opts[:from] = [Zena::Status[v]]
          elsif v.kind_of?(Array)
            opts[:from] = v.map {|e| e.kind_of?(Symbol) ? Zena::Status[e] : e}
          elsif v.kind_of?(Fixnum)
            opts[:from] = [v]
          end

          v = opts[:to]
          if v.kind_of?(Symbol)
            opts[:to] = Zena::Status[v]
          end

          self.transitions << opts.merge(:name => name, :validate => block)
        end

        # Default version class (should usually be overwritten)
        # FIXME: remove !
        def version_class
          Version
        end
      end # ClassMethods

      def self.included(base)
        base.has_many :editions,  :class_name => 'Version',
                 :conditions=>"publish_from <= #{Zena::Db::NOW} AND status = #{Zena::Status[:pub]}", :order=>'lang' #, :inverse_of => :node


        base.before_validation :set_workflow_defaults
        base.validate      :workflow_validation
        base.before_create :workflow_before_create

        base.after_save    :update_status_after_save

        base.class_eval do
          extend  Zena::Use::Workflow::ClassMethods

          # List of allowed *version* transitions with their validation rules. This list
          # concerns the life and death of *a single version*, not the corresponding Node.

          # FIXME: we should not use the same name for 'edit'
          # We could use 'edit', 'create', 'update'
          add_transition(:edit, :from => :red, :to => :red) do |node, version|
            node.can_write?
          end

          add_transition(:edit, :from => -1, :to => :red) do |node, version|
            # create a new node
            node.can_write?
          end

          add_transition(:edit, :from => :pub, :to => :red) do |node, version|
            node.can_write? && version.edited?
          end

          add_transition(:auto_publish, :from => :pub, :to => :pub) do |node, version|
            node.full_drive?
          end

          add_transition(:publish, :from => [-1, :red], :to => :pub) do |node, version|
            node.full_drive?
          end

          add_transition(:publish, :from => [:prop, :prop_with], :to => :pub) do |node, version|
            # editing content when publishing a proposition is not allowed
            if node.full_drive? && !version.edited?
              true
            elsif node.full_drive?
              [false, "You do not have the rights to change a proposition's attributes."]
            else
              false
            end
          end

          add_transition(:publish, :from => (10..49), :to => :pub) do |node, version|
            node.full_drive?
          end

          add_transition(:propose, :from => :red, :to => :prop) do |node, version|
            node.can_write?
          end

          add_transition(:propose, :from => :red, :to => :prop_with) do |node, version|
            node.can_write?
          end

          add_transition(:refuse,  :from => [:prop, :prop_with], :to => :red) do |node, version|
            # refuse and change attributes not allowed
            if node.full_drive? && !version.edited?
              true
            elsif version.edited?
              [false, 'You cannot edit while a proposition is beeing reviewed.']
            else
              false
            end
          end

          add_transition(:unpublish,  :from => :pub, :to => :rem) do |node, version|
            if node.can_drive? && !version.edited?
              true
            elsif version.edited?
              [false, "You cannot unpublish and edit at the same time."]
            else
              false
            end
          end

          add_transition(:remove,  :from => ((21..49).to_a + [70]), :to => :rem) do |node, version|
            node.can_drive? && !version.edited?
          end

          add_transition(:destroy_version,  :from => (-1..20), :to => -1) do |node, version|
            if node.can_drive? && !visitor.is_anon? && (node.versions.count > 1 || node.empty?)
              true
            elsif visitor.is_anon?
              [false, "Anonymous users are not allowed to destroy versions."]
            elsif node.versions.count > 1 || node.empty?
              [false, "Cannot destroy last version: node is not empty."]
            else
              false
            end
          end

          add_transition(:redit, :from => (10..49), :to => :red) do |node, version|
            node.can_drive? && !version.edited?
          end
        end
      end

      # FIXME: remove !
      # def acts_as_version(opts = {})
      #   opts.reverse_merge!({
      #     :class_name => 'Node'
      #   })
      #
      #   belongs_to :node,  :class_name => opts[:class_name] #, :inverse_of => :versions
      #
      # end



      # VERSION
      # FIXME: remove !
      # def version=(v)
      #   if v.kind_of?(Version) && !v.frozen? # TODO: remove !v.frozen? and find why this is loaded during template destroy
      #     v.node = self
      #     @version = v
      #   end
      # end

      # return an array of published versions
      def traductions(opts={})
        if opts == {}
          trad = editions
        else
          trad = editions.find(:all, opts)
        end
        if trad == []
          nil
        else
          trad.map {|t| t.node = self; t; }
        end
      end

      # FIXME: merge this with the logic in build_redaction
      def can_edit?(lang=nil)
        # Has the visitor write access to the node & node is not a proposition ?
        can_write? && !(Zena::Status[:prop]..Zena::Status[:prop_with]).include?(version.status)
      end

      def can_update?
        can_write? && version.status == Zena::Status[:red]
      end

      # FIXME: remove !
      def edit_content!
        redaction && redaction.redaction_content
      end

      # can propose for validation
      def can_propose?
        can_apply? :propose
      end

      # people who can publish:
      # * people who #can_drive? if +status+ >= prop or owner
      # * people who #can_drive? if node is private
      def can_publish?
        can_apply? :publish
      end

      # Can refuse a publication. Same rights as can_publish? if the current version is a redaction.
      def can_refuse?
        can_apply? :refuse
      end

      # Can remove publication
      def can_unpublish?
        can_apply? :unpublish
      end

      # Can remove any other version
      def can_remove?
        can_apply? :remove
      end

      # Can destroy current version ? (only logged in user can destroy)
      def can_destroy_version?
        can_apply? :destroy_version
      end

      def set_current_transition
        version = self.version
        prev = new_record? ? -1 : version.status_was
        curr = version.status
        @current_transition = transition_for(prev, curr)
      end

      def transition_for(prev, curr)
        self.class.transitions.each do |t|
          from, to = t[:from], t[:to]
          if curr == to && from.include?(prev)
            return t
          end
        end
        return nil
      end

      def transition_allowed?(transition)
        from_status = self.version.status
        if transition.kind_of?(Symbol)
          transition = self.class.transitions.detect { |t| t[:name] == transition && t[:from].include?(from_status) }
        end
        transition && (transition[:validate].nil? || transition[:validate].call(self, version))
      end

      #def allowed_transitions
      #  @allowed_transitions ||= begin
      #    prev_status = version.status_was.to_i
      #    allowed = []
      #    self.class.transitions.each do |t|
      #      if t[:from].include?(prev_status)
      #        allowed << t if transition_allowed?(t)
      #      end
      #    end
      #    allowed
      #  end
      #end

      # Returns false is the current visitor does not have enough rights to perform the action.
      def can_apply?(method)
        return true  if visitor.is_su?
        case method
        when :edit
          can_edit?
        when :drive
          can_drive?
        else
          # All the other actions are version transition changes
          transition_allowed?(method)
        end
      end

      # Gateway to all modifications of the node or it's versions.
      def apply(method, *args)
        res = case method
        when :update_attributes
          self.attributes = args.first
          save
        when :propose
          # TODO: replace with version.status = ...
          self.version_attributes = {'status' => args[0] || Zena::Status[:prop]}
          save
        when :publish
          self.version_attributes = {'status' => Zena::Status[:pub]}
          save
        when :refuse, :redit
          self.version_attributes = {'status' => Zena::Status[:red]}
          save
        when :unpublish, :remove
          self.version_attributes = {'status' => Zena::Status[:rem]}
          save
        when :destroy_version
          self.version_attributes = {:__destroy => true}
          save
        end
      end

      def apply_with_callbacks(method, *args)
        if apply_without_callbacks(method, *args)
          # TODO: we should build callback from @current_transition.name
          callback = :"after_#{method}"
          if respond_to?(callback, true)
            send(callback)
          else
            true
          end
        end && after_all # after_all can trigger even if no save operation occured
      end

      alias_method_chain :apply, :callbacks

      def after_all
        true
      end

      # Propose for publication
      def propose(prop_status=Zena::Status[:prop])
        if version.status == Zena::Status[:prop]
          errors.add(:base, 'Already proposed.')
          return false
        end
        apply(:propose, prop_status)
      end

      # Refuse publication
      def refuse
        apply(:refuse)
      end

      # publish if version status is : redaction, proposition, replaced or removed
      # if version to publish is 'rem' or 'red' or 'prop' : old publication => 'replaced'
      # if version to publish is 'rep' : old publication => 'removed'
      def publish(pub_time=nil)
        if version.status == Zena::Status[:pub]
          errors.add(:base, 'Already published.')
          return false
        end
        apply(:publish, pub_time)
      end

      def unpublish
        apply(:unpublish)
      end

      def remove
        apply(:remove)
      end

      # A published version can be removed by the members of the publish group
      # A redaction can be removed by it's owner
      def remove
        if version.status == Zena::Status[:prop]
          errors.add(:base, 'You should refuse the proposition before removing it.')
          return false
        end
        apply(:remove)
      end

      # Edit again a previously published/removed version.
      def redit
        apply(:redit)
      end

      # Versions can be destroyed if they are in 'deleted' status.
      # Destroying the last version completely removes the node (it must thus be empty)
      def destroy_version
        apply(:destroy_version)
      end

      # Set +publish_from+ to the minimum publication time of all editions
      def get_publish_from(ignore_id = nil)
        pub_string  = (self.class.connection.select_one("SELECT publish_from FROM #{version.class.table_name} WHERE node_id = '#{self[:id]}' AND status = #{Zena::Status[:pub]} #{ignore_id ? "AND id != '#{ignore_id}'" : ''} order by publish_from ASC LIMIT 1") || {})['publish_from']
        ActiveRecord::ConnectionAdapters::Column.string_to_time(pub_string)
      end

      # Update an node's attributes or the node's version/content attributes. If the attributes contains only
      # :v_... or :c_... keys, then only the version will be saved. If the attributes does not contain any :v_... or :c_...
      # attributes, only the node is saved, without creating a new version.
      def update_attributes(new_attributes)
        apply(:update_attributes, new_attributes)
      end

      private
        def set_workflow_defaults
          version = self.version

          # Alter version status or set default value
          if version.edited? || version.new_record?
            if version.status_set?
              if version.status == Zena::Status[:pub] &&
                 version.edited? && !full_drive?
                # We silently revert to redaction: refuse auto_publish by setting version status.
                version.status = Zena::Status[:red]
              end
            else
              # Set default version status
              version.status = (current_site[:auto_publish] && full_drive?) ? Zena::Status[:pub] : Zena::Status[:red]
            end
          else
            # keep status value set
          end

          # Set default version's publish_from date
          version.publish_from = version.status.to_i == Zena::Status[:pub] ? (version.publish_from || Time.now) : version.publish_from

          # Store transition before any validation takes place
          set_current_transition
        end

        def workflow_validation

          if transition = @current_transition
            allowed, message = transition_allowed?(transition)
            if allowed
              return true
            else
              errors.add(:base, message || "You do not have the rights to #{transition[:name].to_s.gsub('_', ' ')}.")
            end
            #unless transition_allowed?(transition)
            #  if transition_allowed?(transition)
            #    if [Zena::Status[:prop], Zena::Status[:prop_with]].include?(@original_version.status)
            #      errors.add(:base, "You do not have the rights to change a proposition's attributes.")
            #    else
            #      errors.add(:base, "You do not have the rights to #{transition[:name].to_s.gsub('_', ' ')} and change attributes.")
            #    end
            #  elsif @original_version &&
            #       (Zena::Status[:prop]..Zena::Status[:prop_with]).include?(@original_version.status) &&
            #       version.edited?
            #    errors.add(:base, "You cannot edit while a proposition is beeing reviewed.")
            #  else
            #    errors.add(:base, "You do not have the rights to #{transition[:name].to_s.gsub('_', ' ')}.")
            #  end
            #end
          elsif version.edited? && (Zena::Status[:prop]..Zena::Status[:prop_with]).include?(version.status_was)
            errors.add(:base, 'You cannot edit while a proposition is beeing reviewed.')
          else
            errors.add(:base, 'This transition is not allowed.')
          end
          false
        end

        def workflow_before_create
          self.publish_from = version.publish_from
        end

        # Compute cached 'publish_from' and prepare to update other version status (replace, remove). This
        # method is called before VersionHash::update_vhash but after version was saved.
        def set_current_version_before_update
          version = self.version

          case @current_transition[:name]
          when :edit
            if version.cloned? && @current_transition[:from] == [Zena::Status[:red]] && version.lang == version.stored_workflow[:lang_was]
              @update_status_after_save = {version.previous_id => Zena::Status[:rep]}
            end
          when :redit
            if old_v_id = vhash['w'][version.lang]
              if old_v_id != vhash['r'][version.lang] && old_v_id != version.id
                @update_status_after_save = { old_v_id => Zena::Status[:rep] }
              end
            end
          when :publish
            if old_v_id = vhash['r'][version.lang]
              if old_v_id != version.id
                @update_status_after_save = { old_v_id => version.id > old_v_id ? Zena::Status[:rep] : Zena::Status[:rem] }
              end
            end
            old_w_id = vhash['w'][version.lang]
            if old_w_id != old_v_id && old_w_id != version.id
              @update_status_after_save ||= {}
              @update_status_after_save[old_w_id] = Zena::Status[:rep]
            end

            if self.publish_from.nil? || self.publish_from > version.publish_from
              self.publish_from = version.publish_from
            else
              self.publish_from = get_publish_from(old_v_id)
            end
          when :auto_publish
            if old_v_id = vhash['r'][version.lang]
              if old_v_id != version.id
                @update_status_after_save = { old_v_id => version.id > old_v_id ? Zena::Status[:rep] : Zena::Status[:rem] }
              end
            end
            # publication time might have changed
            if version.stored_workflow[:publish_from_changed]
              # we need to compute new
              self.publish_from = get_publish_from
            end
          when :unpublish
            if vhash['r'].keys == [version.lang]
              # removing last 'readonly' key
              self.publish_from = nil
            else
              self.publish_from = get_publish_from(version.id)
            end
          end

          self.updated_at = Time.now unless changed? # force 'updated_at' sync
          true
        end

        def update_status_after_save
          if @update_status_after_save
            @update_status_after_save.each do |v_id, status|
              self.class.connection.execute "UPDATE #{version.class.table_name} SET status = '#{status}' WHERE id = #{v_id}"
            end
            @update_status_after_save   = nil
          end
          true
        end

        # FIXME: do we need these after_xxxx hooks ? Are they used ?
        # def after_save_xxxxx
        #
        #   # What was the transition ?
        #   if @current_transition
        #     method = "after_#{@current_transition[:name]}"
        #     send(method) if respond_to?(method, true)
        #     @current_transition = nil
        #   end
        #
        #   @allowed_transitions        = nil
        #   true
        # end


        def version_class
          self.class.version_class
        end
    end # Workflow
  end # Use
end # Zena