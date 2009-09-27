module Zena
  module Acts
    module Multiversion
      def self.update_attribute_without_fuss(obj, att, value)
        obj[att] = value
        if value.kind_of?(Time)
          value = value.strftime("'%Y-%m-%d %H:%M:%S'")
        elsif value.nil?
          value = "NULL"
        else
          value = "'#{value}'"
        end
        obj.class.connection.execute "UPDATE #{obj.class.table_name} SET #{att}=#{value} WHERE id=#{obj[:id]}"
      end

      module AddActsAsMethods
        # this is called when the module is included into the 'base' module
        def self.included(base)
          # define class methods
          base.extend Zena::Acts::Multiversion::AddActsAsMethodsImpl
        end
      end

      module AddActsAsMethodsImpl
        def acts_as_multiversioned(opts = {})
          opts.reverse_merge!({
            :class_name => 'Version'
          })

          # TODO: remove for Observers.
          after_save    :after_all

          has_many :versions,  :class_name => opts[:class_name],
                   :order=>"number DESC", :dependent => :destroy #, :inverse_of => :node
          has_many :editions,  :class_name => opts[:class_name],
                   :conditions=>"publish_from <= #{Zena::Db::NOW} AND status = #{Zena::Status[:pub]}", :order=>'lang' #, :inverse_of => :node

          before_validation :set_status_before_validation
          validate      :lock_validation
          validate      :status_validation
          validate      :version_validation

          before_create :cache_version_status_before_create
          before_update :cache_version_status_before_update
          before_save   :multiversion_before_save
          after_save    :multiversion_after_save

          public

          include Zena::Acts::Multiversion::InstanceMethods
          class << self
            include Zena::Acts::Multiversion::ClassMethods
          end

          # List of allowed *version* transitions with their validation rules. This list
          # concerns the life and death of *a single version*, not the corresponding Node.

                                            # not pub                                   pub
          add_transition(:publish, :from => [-1..29,31..49].map(&:to_a).flatten, :to => 50) do |r|
            ( r.can_visible? ||
              ( r.can_manage?  &&  r.private? )
            )
          end
                                            # red        pub
          add_transition(:publish, :from => [30], :to => 50) do |r|
            ( r.can_visible? && r.version.user_id == r.visitor.id ) ||
            ( r.can_manage?  &&  r.private? )
          end
                                                # pub         pub
          add_transition(:auto_publish, :from => [50], :to => 50) do |r|
            (   r.can_visible? ||
              ( r.can_manage?  &&  r.private? )
            )
          end
                                         # red   red_vis     prop
          add_transition(:propose, :from => (30..34), :to => 40) do |r|
            r.version.user_id == r.visitor[:id]
          end

                                         # red   red_vis     prop_with
          add_transition(:propose, :from => (30..34), :to => 35) do |r|
            r.version.user_id == r.visitor[:id]
          end

                                    # prop_with  prop        red
          add_transition(:refuse,  :from => (35..40), :to => 30) do |r|
            (   r.can_visible? ||
              ( r.can_manage?  &&  r.private? )
            )
          end
                                               # pub        rem
          add_transition(:unpublish,  :from => [50], :to => 10) do |r|
            r.can_drive_was_true?
          end
                                         # pub         red
          add_transition(:redit, :from => [50], :to => 30) do |r|
            r.can_edit? && r.version.user_id == visitor.id
          end
                                         # rem+1 red         rem
          add_transition(:remove,  :from => (11..30), :to => 10) do |r|
            (r.can_drive_was_true? || r.version.user_id == visitor.id )
          end
                                                    # red          red
          add_transition(:update_attributes, :from => [30], :to => 30) do |r|
            r.can_write?
          end
                                        # new         red
          add_transition(:edit, :from => [-1], :to => 30) do |r|
            r.can_write?
          end

          #  StatusValidations = {
          #    #from      #validation #to
          #   [(0..49),   50] => :publish, #  :pub
          #   [(30..39),  40] => :propose, #  :prop
          #   [(30..39),  35] => :propose, #  :prop_with
          #   [(50..50),  30] => :redit,
          #   [(30..30),  30] => :update_attributes,
          #   [(40..49),  30] => :refuse,
          #  }.freeze
        end

        def acts_as_version(opts = {})
          opts.reverse_merge!({
            :class_name => 'Node'
          })

          belongs_to :node,  :class_name => opts[:class_name] #, :inverse_of => :versions
          class_eval do
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

        def act_as_content
          class_eval do
            def preload_version(v)
              @version = v
            end

            # FIXME: replace by belongs_to :version ?
            def version
              @version ||= Version.find(self[:version_id])
            end

            # Return true if the version would be edited by the attributes
            def would_edit?(new_attrs)
              new_attrs.each do |k,v|
                if self.class.attr_public?(k.to_s)
                  return true if field_changed?(k, self.send(k), v)
                end
              end
              false
            end
          end
        end
      end # AddActsAsMethodsImpl

      module InstanceMethods

        # VERSION
        def version=(v)
          if v.kind_of?(Version)
            @version = v
          end
        end

        # FIXME: merge this with the logic in edit!
        def can_edit?
          can_edit_lang?
        end

        # FIXME: merge this with the logic in edit!
        def can_edit_lang?(lang=nil)
          return false unless can_write?
          if lang
            # can we create a new redaction for this lang ?
            v = versions.find(:first, :select => 'id', :conditions=>["status >= #{Zena::Status[:red]} AND status < #{Zena::Status[:pub]} AND lang=?", lang])
            v == nil
          else
            # can we create a new redaction in the current context ?
            # there can only be one redaction/proposition per lang per node. Only the owner of the red can edit
            v = versions.find(:first, :select => 'id,status,user_id', :conditions=>["status >= #{Zena::Status[:red]} AND status < #{Zena::Status[:pub]} AND lang=?", visitor.lang])
            v == nil || (v.status == Zena::Status[:red] && v.user_id == visitor[:id])
          end
        rescue ActiveRecord::RecordNotFound
          true
        end

        def edit_content!
          redaction && redaction.redaction_content
        end

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

        # can propose for validation
        def can_propose?
          can_apply?(:propose)
        end

        # people who can publish:
        # * people who #can_visible? if +status+ >= prop or owner
        # * people who #can_manage? if node is private
        def can_publish?
          can_apply?(:publish)
        end

        # Can refuse a publication. Same rights as can_publish? if the current version is a redaction.
        def can_refuse?
          can_apply?(:refuse)
        end

        # Can remove publication
        def can_unpublish?(v=version)
          can_apply?(:unpublish, v)
        end

        # Can destroy current version ? (only logged in user can destroy)
        def can_destroy_version?(v=version)
          can_apply?(:destroy_version, v)
        end

        # Return true if the node is not a reference for any other node
        def empty?
          return true if new_record?
          0 == self.class.count_by_sql("SELECT COUNT(*) FROM #{self.class.table_name} WHERE #{ref_field} = #{self[:id]}")
        end

        def current_transition
          transition_for(nil, nil)
        end

        def transition_for(prev, curr)
          prev ||= version.new_record? ? -1 : version.status_was.to_i
          curr ||= version.status.to_i
          self.class.transitions.each do |t|
            from, to = t[:from], t[:to]
            if curr == to && from.include?(prev)
              return t
            end
          end
          return nil
        end

        def transition_allowed?(transition = self.current_transition, v = self.version)
          if transition.kind_of?(Symbol)
            prev_status = v.new_record? ? -1 : v.status_was.to_i
            transition = self.class.transitions.select { |t| t[:name] == transition && t[:from].include?(prev_status) ? t : nil}[0]
          end
          transition && (transition[:validate].nil? || transition[:validate].call(self))
        end

        def allowed_transitions
          @allowed_transitions ||= begin
            prev_status = version.status_was.to_i
            allowed = []
            self.class.transitions.each do |t|
              if t[:from].include?(prev_status)
                allowed << t if transition_allowed?(t)
              end
            end
            allowed
          end
        end

        # Returns false is the current visitor does not have enough rights to perform the action.
        def can_apply?(method, v=version)
          return true  if visitor.is_su?
          prev_status = v.status_was.to_i
          case method
          when :destroy_version
            # anonymous users cannot destroy
            can_drive? && prev_status == Zena::Status[:rem] && !visitor.is_anon? && (self.versions.count > 1 || empty?)
          when :edit
            can_edit_lang?
          when :drive
            can_drive?
          else
            # All the other actions are version transition changes
            transition_allowed?(method, v)
          end
        end

        # Gateway to all modifications of the node or it's versions.
        def apply(method, *args)
          res = case method
          when :update_attributes
            self.attributes = args[0]
            save
          when :propose
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
            if versions.count == 1
              self.destroy # will destroy last version
            else
              if version.destroy
                # remove from versions list
                if self.versions.loaded?
                  self.versions -= [version]
                end
                true
              end
            end
          when :backup
            # FIXME: this does not work !
            version.status = Zena::Status[:rep]
            @redaction = nil
            redaction.save if version.save
          end
        end

        # Propose for publication
        def propose(prop_status=Zena::Status[:prop])
          apply(:propose, prop_status)
        end

        # Backup a redaction (create a new version)
        # TODO: test
        def backup
          apply(:backup)
        end

        # Refuse publication
        def refuse
          apply(:refuse)
        end

        # publish if version status is : redaction, proposition, replaced or removed
        # if version to publish is 'rem' or 'red' or 'prop' : old publication => 'replaced'
        # if version to publish is 'rep' : old publication => 'removed'
        def publish(pub_time=nil)
          apply(:publish, pub_time)
        end

        def unpublish
          apply(:unpublish)
        end

        # A published version can be removed by the members of the publish group
        # A redaction can be removed by it's owner
        def remove
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
        def get_publish_from(ignore_current = true)
          pub_string  = (self.class.connection.select_one("SELECT publish_from FROM #{version.class.table_name} WHERE node_id = '#{self[:id]}' AND status = #{Zena::Status[:pub]} #{ignore_current ? "AND id != '#{version.id}'" : ''} order by publish_from ASC LIMIT 1") || {})['publish_from']
          ActiveRecord::ConnectionAdapters::Column.string_to_time(pub_string)
        end

        # Set +max_status+ to the maximum status of all versions
        def get_max_status(ignore_current = true)
          vers_table = version.class.table_name
          new_max    = (self.class.connection.select_one("select #{vers_table}.status from #{vers_table} WHERE #{vers_table}.node_id='#{self[:id]}' #{ignore_current ? "AND id != '#{version.id}'" : ''} order by #{vers_table}.status DESC LIMIT 1") || {})['status']
          new_max.to_i
        end

        # Update an node's attributes or the node's version/content attributes. If the attributes contains only
        # :v_... or :c_... keys, then only the version will be saved. If the attributes does not contain any :v_... or :c_...
        # attributes, only the node is saved, without creating a new version.
        def update_attributes(new_attributes)
          apply(:update_attributes,new_attributes)
        end

        # Return the current version. If @version was not set, this is a normal find or a new record. We have to find
        # a suitable edition :
        # * if new_record?, create a new redaction
        # * find user redaction or proposition in the current lang
        # * find an edition for current lang
        # * find an edition in the reference lang for this node
        # * find the first publication
        # If 'key' is set to :pub, only find the published versions. If key is a number, find the version with this number.
        def version(key=nil) #:doc:
          if !key.nil? && !key.kind_of?(Symbol)
            v = versions.find(:first,
              :conditions => [ "((status = #{Zena::Status[:red]} AND user_id = ?) OR status <> #{Zena::Status[:red]}) AND number = ?", visitor.id, key])
            raise ActiveRecord::RecordNotFound unless v
            v.node = self
            @version = v
          else
            @version ||= if new_record?
              v = version_class.new('lang' => visitor.lang)
              v.user_id = visitor.id
              v.node = self
              v
            else
              min_status = (key == :pub) ? Zena::Status[:pub] : Zena::Status[:red]
              if max_status >= Zena::Status[:red]
                # normal version
                v = versions.find(:first,
                  :select     => "*, (lang = #{Node.connection.quote(visitor.lang)}) as lang_ok, (lang = #{Node.connection.quote(ref_lang)}) as ref_ok",
                  :conditions => [ "(status >= #{min_status} AND user_id = ?) OR status >= #{can_drive? ? [min_status, Zena::Status[:prop]].max : Zena::Status[:pub]}", visitor.id],
                  :order      => "lang_ok DESC, ref_ok DESC, status ASC, publish_from ASC")
                v.node = self if v # FIXME: remove when :inverse_of moves in Rails stable
                v
              else
                # drive only
                v = versions.find(:first,
                  :select     => "*, (lang = #{Node.connection.quote(visitor.lang)}) as lang_ok, (lang = #{Node.connection.quote(ref_lang)}) as ref_ok",
                  :order      => "lang_ok DESC, ref_ok DESC, status ASC, publish_from ASC")
                v.node = self if v # FIXME: remove when :inverse_of moves in Rails stable
                v
              end
            end
          end
        end

        # Define attributes for the current redaction.
        def version_attributes=(attrs)
          edit!(attrs)
          version.attributes = attrs
        end

        # Creates a new redaction ready to be edited.
        # TODO: this should be renamed to 'make_redaction' or equivalent.
        def edit!(version_attributes = nil)
          target_status = version_attributes ? version_attributes['status'] : nil
          would_edit    = version_attributes ? version.would_edit?(version_attributes) : true
          @redaction ||= begin
            target_status ||= current_site[:auto_publish] ? Zena::Status[:pub] : Zena::Status[:red]
            v = self.version
            if new_record? || !would_edit
              # nothing to do
              @version
            elsif v.lang != ((version_attributes || {})['lang'] || visitor.lang)
              # clone
              build_redaction(v, target_status)
            elsif v.user_id == visitor.id
              # author is editing
              if v.status == Zena::Status[:red]
                # use current version
                @version
              elsif v.status      == Zena::Status[:pub] &&
                    target_status == Zena::Status[:pub] &&
                    Time.now < v.updated_at_was + current_site[:redit_time].to_i && # redit time
                    transition_allowed?(transition_for(50, 50))
                @version
              elsif v.status == Zena::Status[:pub]
                # make a new redaction
                build_redaction(v, target_status)
              else
                # other status, changes not allowed
                # create dummy for error reporting
                build_redaction(v, target_status)
              end
            else
              # new author wants to edit
              if v.status == Zena::Status[:pub]
                # make a redaction out of this version
                build_redaction(v, target_status)
              else
                # proposition, other status
                # create dummy for error reporting
                build_redaction(v, target_status)
              end
            end
          end
        end

        alias redaction edit!

        def build_redaction(version, status)
          @version = version.clone('status' => status)
        end

        # Returns a lock (responds to 'user') for the specified lang or nil when
        # a redaction or proposition for the given lang exists and we try to create
        # a redaction or proposition.
        def lang_locked?(l = visitor.lang, v = self.version)
          return false if v.status < Zena::Status[:red] || v.status == Zena::Status[:pub]
          versions.find(:first, :select => 'user_id', :conditions => ["lang = ? AND status >= #{Zena::Status[:red]} AND status < #{Zena::Status[:pub]} AND id <> ?", l, v.id.to_i])
        end

        private
          def set_status_before_validation
            multiversion_before_validation_on_create if new_record?
            if v = @redaction
              v.status ||= Zena::Status[:red]
              if current_site[:auto_publish]
                v.status = Zena::Status[:pub] if v.status == Zena::Status[:red]
              end

              if v.edited? && v.status == Zena::Status[:pub] && !transition_allowed?
                # remove auto publish
                v.status = Zena::Status[:red]
              end
              v.publish_from = v.status.to_i == Zena::Status[:pub] ? (v.publish_from || Time.now) : v.publish_from
            end
          end

          # Called before create validations, this method is responsible for setting up
          # the initial redaction.
          def multiversion_before_validation_on_create
            self.edit! unless @redaction
            self.max_status   = version.status
            self.publish_from = version.publish_from
          end

          def lock_validation
            if @redaction && @redaction.should_save? && l = lang_locked?(@redaction.lang, @redaction)
              if l.user_id == visitor.id
                errors.add(:base, 'You cannot edit while you have a proposition waiting for approval.')
              else
                errors.add(:base, "(#{l.user.login}) is editing this node")
              end
            end
          end

          def status_validation
            return true unless @redaction && @redaction.should_save?
            if t = current_transition
              errors.add(:base, "You do not have the rights to #{t[:name].to_s.gsub('_', ' ')}") unless transition_allowed?(t)
            else
              errors.add(:base, 'This transition is not allowed.')
            end
          end

          def version_validation
            return true unless @redaction
            unless @redaction.valid?
              @redaction.errors.each_error do |attribute, message|
                attribute = "version_#{attribute}"
                errors.add(attribute, message) unless errors[attribute] # FIXME: rails 3: if errors[attribute].empty?
              end
            end
          end

          def cache_version_status_before_create
            self.max_status   = version.status
            self.publish_from = version.publish_from
            true
          end

          def cache_version_status_before_update
            return true unless @version && (@version.status_changed? || @version.new_record?)
            # current_transition cannot be nil here (verified in status_validation)
            self.updated_at = Time.now
            case current_transition[:name]
            when :publish
              self.max_status   = Zena::Status[:pub]
              if self.publish_from
                self.publish_from = [self.publish_from, version.publish_from].min
              else
                self.publish_from = version.publish_from
              end
              @old_publication_to_remove = [Zena::Db.fetch_ids("SELECT id FROM versions WHERE node_id = '#{self[:id]}' AND lang = '#{version[:lang]}' AND status = '#{Zena::Status[:pub]}' AND id != '#{version.id}'"), (version.status_was == Zena::Status[:rep] ? Zena::Status[:rem] : Zena::Status[:rep])]
            when :auto_publish
              # publication time might have changed
              if version.publish_from_changed?
                # we need to compute new
                self.publish_from = [get_publish_from, version.publish_from].min
              end
            when :update_attributes
              # nothing to do
            when :unpublish, :remove, :redit, :refuse
              # moving down
              self.max_status = [get_max_status, version.status.to_i].max
            when :propose
              # moving up
              self.max_status = [max_status_was.to_i, version.status.to_i].max
            else
            end
            true
          end

          def multiversion_before_save
            @version_or_content_updated_but_not_saved = !changed? && (@version.changed? || (@version.content && @version.content.changed?))
            true
          end

          def multiversion_after_save

            if @redaction && @redaction.should_save?
              changes = @redaction.changes
              return false unless @redaction.save
              self.versions.reset # TODO: it would be nice if we didn't need this...

              # What was the transition ?
              if status_changes = changes['status']
                transition = transition_for(status_changes[-2], status_changes[-1])
                method = "after_#{transition[:name]}"
                send(method) if respond_to?(method, true)
              end
            end

            if @old_publication_to_remove
              self.class.connection.execute "UPDATE #{version.class.table_name} SET status = '#{@old_publication_to_remove[1]}' WHERE id IN (#{@old_publication_to_remove[0].join(', ')})" unless @old_publication_to_remove[0] == []
            end

            if @version_or_content_updated_but_not_saved
              # not saved, set updated_at manually
              update_attribute_without_fuss(:updated_at, @version.updated_at)
            end

            @changed_before_save       = nil
            @allowed_transitions       = nil
            @old_publication_to_remove = nil
            @redaction                 = nil
            true
          end

          def update_attribute_without_fuss(att, value)
            Multiversion.update_attribute_without_fuss(self, att, value)
          end

          # Any attribute starting with 'v_' belongs to the 'version' or 'redaction'
          # Any attribute starting with 'c_' belongs to the 'version' or 'redaction' content
          # FIXME: performance: create methods on the fly so that next calls will not pass through 'method_missing'. #189.
          # FIXME: this should not be used anymore. Remove.
          def method_missing(meth, *args)
            if meth.to_s =~ /^(v_|c_|d_)(([\w_\?]+)(=?))$/
              target = $1
              method = $2
              value  = $3
              mode   = $4
              if mode == '='
                begin
                  # set
                  unless recipient = redaction
                    # remove trailing '='
                    redaction_error(meth.to_s[0..-2], "could not be set (no redaction)")
                    return
                  end

                  case target
                  when 'c_'
                    if recipient.content_class && recipient = recipient.redaction_content
                      recipient.send(method,*args)
                    else
                      redaction_error(meth.to_s[0..-2], "cannot be set") # remove trailing '='
                    end
                  when 'd_'
                    recipient.dyn[method[0..-2]] = args[0]
                  else
                    recipient.send(method,*args)
                  end
                rescue NoMethodError
                  # bad attribute, just ignore
                end
              else
                # read
                recipient = version
                if target == 'd_'
                  version.dyn[method]
                else
                  recipient = recipient.content if target == 'c_'
                  return nil unless recipient
                  begin
                    recipient.send(method,*args)
                  rescue NoMethodError
                    # bad attribute
                    return nil
                  end
                end
              end
            else
              super
            end
          end

          def version_class
            self.class.version_class
          end
      end # InstanceMethods

      module ClassMethods
        # FIXME: should use class inheritable attribute
        @@transitions = []

        def transitions
          @@transitions
          # something like this does not work: @@transitions[self] ||= []
        end

        def add_transition(name, args, &block)
          self.transitions << args.merge(:name => name, :validate => block)
        end

        # Default version class (should usually be overwritten)
        def version_class
          Version
        end

        # Find a node based on a version id
        def version(version_id)
          version = Version.find(version_id.to_i)
          node = self.find(version.node_id)
          node.version = version
          # FIXME: remove this
          node.eval_with_visitor 'errors.add("base", "you do not have the rights to do this") unless version.status == 50 || can_drive? || version.user_id == visitor[:id]'
        end
      end # ClassMethods
    end # Multiversion
  end # Acts
end # Zena