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

  module Acts

    module Multiversion

      def acts_as_multiversioned(opts = {})
        opts.reverse_merge!({
          :class_name => 'Version'
        })

        # TODO: remove for Observers.
        after_save    :after_all

        has_many :versions,  :class_name => opts[:class_name],
                 :order=>"number DESC", :dependent => :destroy  #, :inverse_of => :node

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

        include Zena::Acts::Multiversion::InstanceMethods
        extend  Zena::Acts::Multiversion::ClassMethods

        # List of allowed *version* transitions with their validation rules. This list
        # concerns the life and death of *a single version*, not the corresponding Node.

        add_transition(:update_attributes, :from => :red, :to => :red) do |r|
          r.can_write?
        end
                                      # new
        add_transition(:edit, :from => -1, :to => :red) do |r|
          r.can_write?
        end

        add_transition(:auto_publish, :from => :pub, :to => :pub) do |r|
          r.can_drive?
        end
                                          # not pub
        add_transition(:publish, :from => ((-1..70).to_a - [50]), :to => :pub) do |r|
          r.full_drive?
        end

        add_transition(:propose, :from => :red, :to => :prop) do |r|
          r.can_write?
        end

        add_transition(:propose, :from => :red, :to => :prop_with) do |r|
          r.can_write?
        end

        add_transition(:refuse,  :from => [:prop, :prop_with], :to => :red) do |r|
          r.full_drive?
        end

        add_transition(:unpublish,  :from => :pub, :to => :rem) do |r|
          r.can_drive?
        end

        add_transition(:remove,  :from => ((21..49).to_a + [70]), :to => :rem) do |r|
          r.can_drive?
        end

        add_transition(:destroy_version,  :from => (-1..20), :to => -1) do |r|
          r.can_drive? && !visitor.is_anon? && (r.versions.count > 1 || r.empty?)
        end

        add_transition(:redit, :from => (10..49), :to => :red) do |r|
          r.can_drive?
        end
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
              if type = self.class.safe_method_type([k])
                return true if field_changed?(k, self.send(type[:method]), v)
              end
            end
            false
          end
        end
      end

      module InstanceMethods

        # VERSION
        def version=(v)
          if v.kind_of?(Version)
            @version = v
          end
        end

        def vhash
          @vhash ||= JSON.parse(self[:vhash] || '{"r":{}, "w":{}}')
        end

        def update_vhash(version)
          # FIXME: should also update publish_from & old_publications...
          # puts [@current_transition[:name], version.status, version.id, vhash].inspect
          case @current_transition[:name]
          when :edit
            vhash['w'][version.lang] = version.id
          when :redit
            if old_redaction_id = vhash['w'][version.lang]
              if old_redaction_id != vhash['r'][version.lang]
                self.class.connection.execute "UPDATE #{version.class.table_name} SET status = '#{Zena::Status[:rem]}' WHERE id = #{old_redaction_id}"
              end
            end
            vhash['w'][version.lang] = version.id
          when :publish
            if old_publication_id = vhash['r'][version.lang]
              self.class.connection.execute "UPDATE #{version.class.table_name} SET status = '#{version.id > old_publication_id ? Zena::Status[:rep] : Zena::Status[:rem]}' WHERE id = #{old_publication_id}"
            end
            vhash['r'][version.lang] = vhash['w'][version.lang] = version.id
          when :unpublish
            vhash['r'].delete(version.lang)
          when :remove
            if v_id = vhash['r'][version.lang]
              vhash['w'][version.lang] = v_id
            end
          end
          # puts [@current_transition[:name], version.status, version.id, vhash].inspect
          # puts "---------------------"
          self[:vhash] = vhash.to_json
        end

        def rebuild_vhash
          r_hash, w_hash = {}, {}
          vhash = {'r' => r_hash, 'w' => w_hash}
          lang  = nil
          self.publish_from = n_pub = nil
          connection.select_all("SELECT id,lang,status,publish_from FROM #{Version.table_name} WHERE node_id = #{self.id} ORDER BY lang ASC, status DESC", "Version Load").each do |record|
            if record['lang'] != lang
              lang   = record['lang']
              # highest status for this lang
              if record['status'].to_i == Zena::Status[:pub]
                # ok for readers & writers
                w_hash[lang] = r_hash[lang] = record['id'].to_i
                v_pub = DateTime.parse(record['publish_from']) rescue Time.now
                if n_pub.nil? || v_pub < n_pub
                  n_pub = v_pub
                end
              else
                # too high, only ok for writers
                w_hash[lang] = record['id'].to_i
              end
            elsif record['status'].to_i == Zena::Status[:pub]
              # ok for readers
              r_hash[lang] = record['id'].to_i
              v_pub = DateTime.parse(record['publish_from']) rescue Time.now
              if n_pub.nil? || v_pub < n_pub
                n_pub = v_pub
              end
            end
          end
          self[:publish_from] = n_pub
          self[:vhash] = vhash.to_json
          @vhash = vhash
        end

        def version_id(force_pub = false)
          access = (!force_pub && can_write?) ? vhash['w'] : vhash['r']
          access[visitor.lang] || access[ref_lang] || access.values.first
        end

        # FIXME: merge this with the logic in edit!
        def can_edit?(lang=nil)
          # Has the visitor write access to the node & node is not a proposition ?
          can_write? && !(Zena::Status[:prop]..Zena::Status[:prop_with]).include?(version.status)

            # It can be only one readation per lang.
              # v = versions.find(:first, :select => 'id', :conditions=>["status > #{Zena::Status[:pub]} AND status < #{Zena::Status[:red]} AND lang=?", lang])
              # v == nil
            #
              # can we create a new redaction in the current context ?
              # there can only be one redaction/proposition per lang per node. Only the owner of the red can edit
              # v = versions.find(:first, :select => 'id,status,user_id', :conditions=>["status > #{Zena::Status[:pub]} AND status < #{Zena::Status[:red]} AND lang=?", visitor.lang])
              # v == nil || (v.status == Zena::Status[:red] && v.user_id == visitor[:id])
        end

        def can_update?
          can_write? && version.status == Zena::Status[:red]
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
        # * people who #can_drive? if +status+ >= prop or owner
        # * people who #can_drive? if node is private
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

        # Can remove any other version
        def can_remove?(v=version)
          can_apply?(:remove, v)
        end


        # Can destroy current version ? (only logged in user can destroy)
        def can_destroy_version?(v=version)
          can_apply?(:destroy_version, v)
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
            transition = self.class.transitions.detect { |t| t[:name] == transition && t[:from].include?(prev_status) }
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
          when :edit
            can_edit?
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
            self.attributes = args.first
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
          if version.status == Zena::Status[:prop]
            errors.add(:base, 'Already proposed.')
            return false
          end
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
        def get_publish_from(ignore_current = true)
          pub_string  = (self.class.connection.select_one("SELECT publish_from FROM #{version.class.table_name} WHERE node_id = '#{self[:id]}' AND status = #{Zena::Status[:pub]} #{ignore_current ? "AND id != '#{version.id}'" : ''} order by publish_from ASC LIMIT 1") || {})['publish_from']
          ActiveRecord::ConnectionAdapters::Column.string_to_time(pub_string)
        end

        # Update an node's attributes or the node's version/content attributes. If the attributes contains only
        # :v_... or :c_... keys, then only the version will be saved. If the attributes does not contain any :v_... or :c_...
        # attributes, only the node is saved, without creating a new version.
        def update_attributes(new_attributes)
          if can_write? && !(Zena::Status[:prop] .. Zena::Status[:prop_with]).include?(version.status)
            apply(:update_attributes,new_attributes)
          elsif can_drive?
            # FIXME: this will not work if we write "versions_attributes => {'status' => 50}"
            # FIXME: string vs symbols (keys are always strings from the web)
            # FIXME: this should go into the validation, not here...
            unvalid_keys = new_attributes.keys - [:v_status, :v_publish_from]
            unvalid_keys.empty? ? apply(:update_attributes, new_attributes ) : false
          else
            # FIXME: move this into validation when we have vhash
            errors.add('You are not allowed to write.')
            false
          end
        end

        # Return the current version. If @version was not set, this is a normal find or a new record.
        # TODO: document rules to find version.
        def version(force_pub = false) #:doc:
          @version ||= if new_record?
            v = version_class.new('lang' => visitor.lang)
            v.user_id = visitor.id
            v.node = self
            v
          else
            v = Version.find(version_id(force_pub))
            v.node = self
            v
          end
        end

        # Define attributes for the current redaction.
        def version_attributes=(attrs)
          edit!(attrs)
          version.attributes = attrs
        end

        # Creates a new redaction ready to be edited.
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
                # autopublish
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
              elsif v.status == Zena::Status[:red]
                @old_redaction_to_replace = v
                build_redaction(v, target_status)
              elsif v.status > Zena::Status[:pub]
                # proposition: cannot edit here
                build_redaction(v, target_status)
              else
                @old_redaction_to_replace = v
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
            self[:vhash] = @vhash.to_json if @vhash
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
            if @current_transition = self.current_transition
              errors.add(:base, "You do not have the rights to #{@current_transition[:name].to_s.gsub('_', ' ')}.") unless transition_allowed?(@current_transition)
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
            self.publish_from = version.publish_from
            true
          end

          def cache_version_status_before_update
            return true unless @version && (@version.status_changed? || @version.new_record?)
            # current_transition cannot be nil here (verified in status_validation)
            self.updated_at = Time.now
            case current_transition[:name]
            when :publish
              if self.publish_from
                self.publish_from = [self.publish_from, version.publish_from].min
              else
                self.publish_from = version.publish_from
              end
              @old_publication_to_replace = [Zena::Db.fetch_ids("SELECT id FROM versions WHERE node_id = '#{self[:id]}' AND lang = '#{version[:lang]}' AND status = '#{Zena::Status[:pub]}' AND id != '#{version.id}'"), (version.status_was == Zena::Status[:rep] ? Zena::Status[:rem] : Zena::Status[:rep])]
            when :auto_publish
              # publication time might have changed
              if version.publish_from_changed?
                # we need to compute new
                self.publish_from = [get_publish_from, version.publish_from].min
              end
            else
            end
            true
          end

          def multiversion_before_save
            @version_or_content_updated_but_not_saved = !changed? && (@version.changed? || (@version.content && @version.content.changed?))
            if @redaction && @redaction.should_save?
              changes = @redaction.changes
              return false unless @redaction.save
              update_vhash(@redaction)
            end
            @redaction = nil
            true
          end

          def multiversion_after_save

            # What was the transition ?
            if @current_transition
              method = "after_#{@current_transition[:name]}"
              send(method) if respond_to?(method, true)
              @current_transition = nil
            end

            if @old_publication_to_replace
              self.class.connection.execute "UPDATE #{version.class.table_name} SET status = '#{@old_publication_to_replace[1]}' WHERE id IN (#{@old_publication_to_replace[0].join(', ')})" unless @old_publication_to_replace[0] == []
            end

            if @old_redaction_to_replace
              self.class.connection.execute "UPDATE #{version.class.table_name} SET status = '#{Zena::Status[:rep]}' WHERE id = #{@old_redaction_to_replace.id}"
            end

            if @version_or_content_updated_but_not_saved
              # not saved, set updated_at manually
              Zena::Db.set_attribute(self, :updated_at, @version.updated_at)
            end

            @changed_before_save        = nil
            @allowed_transitions        = nil
            @old_publication_to_replace = nil
            @old_redaction_to_replace   = nil
            true
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
        def version_class
          Version
        end
      end # ClassMethods
    end # Multiversion
  end # Acts
end # Zena