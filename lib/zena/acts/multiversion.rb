module Zena
  module Acts
    module Multiversion
      # this is called when the module is included into the 'base' module
      def self.included(base)
        # add all methods from the module "AddActsAsMethod" to the 'base' module
        base.extend AddActsAsMethods
      end
      
      module AddActsAsMethods
        def acts_as_multiversioned(opts = {})
          opts.reverse_merge!({
            :class_name => 'Version'
          })
          
          # TODO: remove for Observers.
          after_save        :after_all
          
          has_many :versions, :inverse => self.to_s.underscore,  :class_name => opts[:class_name],
                   :order=>"number DESC", :dependent => :destroy
          has_many :editions, :inverse => self.to_s.underscore,  :class_name => opts[:class_name],
                   :conditions=>"publish_from <= now() AND status = #{Zena::Status[:pub]}", :order=>'lang'
          
          before_validation :set_status_before_validation
          validate      :lock_validation
          validate      :status_validation
          validate      :redaction_validation
          
          before_create :cache_version_status_before_create
          before_update :cache_version_status_before_update
          after_save    :multiversion_after_save
          
          public
          
          include Zena::Acts::MultiversionImpl::InstanceMethods
          class << self
            include Zena::Acts::MultiversionImpl::ClassMethods
          end
                                           # not pub         pub
          add_transition(:publish, :from => (-1..49), :to => 50) do |r|
            ps = r.version.new_record? ? -1 : r.version.status_was.to_i
            ( ( r.can_visible? && (ps >  Zena::Status[:red] ||
                                   ps == Zena::Status[:rep] ||
                                   r.version.user_id == r.visitor.id) ) ||
              ( r.can_manage?  &&  r.private? )
            )
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
      end
    end
    
    module MultiversionImpl
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
            v = versions.find(:first, :conditions=>["status >= #{Zena::Status[:red]} AND status < #{Zena::Status[:pub]} AND lang=?", lang])
            v == nil
          else
            # can we create a new redaction in the current context ?
            # there can only be one redaction/proposition per lang per node. Only the owner of the red can edit
            v = versions.find(:first, :conditions=>["status >= #{Zena::Status[:red]} AND status < #{Zena::Status[:pub]} AND lang=?", visitor.lang])
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
          trad == [] ? nil : trad
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
        
        def transition_allowed?(transition = self.current_transition)
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
          when :update_attributes
            can_write?
          when :drive # ?
            can_drive?
          when :propose, :backup
            v.user_id == visitor[:id] && prev_status == Zena::Status[:red]
          when :refuse
            prev_status > Zena::Status[:red] && can_apply?(:publish)
          when :publish  
            if prev_status == Zena::Status[:pub]
              errors.add('base', 'already published.')
              return false
            end
            prev_status < Zena::Status[:pub] && 
            ( ( can_visible_was_true? && (prev_status > Zena::Status[:red] || prev_status == Zena::Status[:rep] || v.user_id_was == visitor[:id]) ) ||
              ( can_manage_was_true?  && private_was_true? )
            )
          when :unpublish
            can_drive? && prev_status == Zena::Status[:pub]
          when :remove
            (can_drive? || v.user_id == visitor[:id] ) && prev_status <= Zena::Status[:red] && prev_status > Zena::Status[:rem]
          when :redit
            can_edit? && v.user_id == visitor[:id]
          when :edit
            can_edit?
          when :destroy_version
            # anonymous users cannot destroy
            can_drive? && prev_status == Zena::Status[:rem] && !visitor.is_anon? && (self.versions.count > 1 || empty?)
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
              version.destroy && self.destroy
            else
              version.destroy
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
          @version ||= if new_record?
            v = version_class.new('lang' => visitor.lang)
            v.user_id = visitor.id
            v.node = self
            v
          elsif key.nil? || key.kind_of?(Symbol)
            min_status = (key == :pub) ? Zena::Status[:pub] : Zena::Status[:red]
            if max_status >= Zena::Status[:red]
              # normal version
              versions.find(:first, 
                :select     => "*, (lang = #{Node.connection.quote(visitor.lang)}) as lang_ok, (lang = #{Node.connection.quote(ref_lang)}) as ref_ok",
                :conditions => [ "(status >= #{min_status} AND user_id = ? AND lang = ?) OR status >= #{can_drive? ? [min_status, Zena::Status[:prop]].max : Zena::Status[:pub]}", visitor.id, visitor.lang ],
                :order      => "lang_ok DESC, ref_ok DESC, status ASC, publish_from ASC")
            else
              # drive only
              versions.find(:first, 
                :select     => "*, (lang = #{Node.connection.quote(visitor.lang)}) as lang_ok, (lang = #{Node.connection.quote(ref_lang)}) as ref_ok",
                :order      => "lang_ok DESC, ref_ok DESC, status ASC, publish_from ASC")
            end
          else
            v = versions.find(:first,
              :conditions => [ "(status >= #{Zena::Status[:red]} AND user_id = ? AND lang = ?) OR status >= #{can_drive? ? Zena::Status[:prop] : Zena::Status[:pub]} AND number = ?", visitor.id, visitor.lang, key])
            raise ActiveRecord::RecordNotFound unless v
            v
          end
=begin
          return @version if @version
          
          if key && !key.kind_of?(Symbol) && !new_record?
            if visitor.is_su?
              @version = secure!(Version) { Version.find(:first, :conditions => ["node_id = ? AND number = ?", self[:id], key]) }
            elsif can_drive?
              @version = secure!(Version) { Version.find(:first, :conditions => ["node_id = ? AND number = ? AND (user_id = ? OR status <> ?)", self[:id], key, visitor[:id], Zena::Status[:red]]) }
            else
              @version = secure!(Version) { Version.find(:first, :conditions => ["node_id = ? AND number = ? AND (user_id = ? OR status >= ?)", self[:id], key, visitor[:id], Zena::Status[:pub]]) }
            end
          else
            min_status = (key == :pub) ? Zena::Status[:pub] : Zena::Status[:red]
            
            if new_record?
              @version = version_class.new
              # owner and lang set in secure_scope
              @version.status = Zena::Status[:red]
            elsif can_drive?
              # sees propositions
              lang = visitor.lang.gsub(/[^\w]/,'')
              @version =  Version.find(:first,
                            :select=>"*, (lang = '#{lang}') as lang_ok, (lang = '#{ref_lang}') as ref_ok",
                            :conditions=>[ "((status >= ? AND user_id = ? AND lang = ?) OR status > ?) AND node_id = ?", 
                                            min_status, visitor[:id], lang, Zena::Status[:red], self[:id] ],
                            :order=>"lang_ok DESC, ref_ok DESC, status ASC ")
              if !@version
                @version = versions.find(:first, :order=>'id DESC')
              end
            else
              # only own redactions and published versions
              lang = visitor.lang.gsub(/[^\w]/,'')
              @version =  Version.find(:first,
                            :select=>"*, (lang = '#{lang}') as lang_ok, (lang = '#{ref_lang}') as ref_ok",
                            :conditions=>[ "((status >= ? AND user_id = ? AND lang = ?) OR status = ?) and node_id = ?", 
                                            min_status, visitor[:id], lang, Zena::Status[:pub], self[:id] ],
                            :order=>"lang_ok DESC, ref_ok DESC, status ASC, publish_from ASC")

            end
            
            if @version.nil?
              raise Exception.new("#{self.class} #{self[:id]} does not have any version !!")
            end
          end
          @version.node = self if @version # preload self as node in version
          @version
=end
        end
        
        # Define attributes for the current redaction.
        def version_attributes=(attrs)
          edit!(attrs['status'], version.would_edit?(attrs))
          version.attributes = attrs
        end

        def edit!(target_status = nil, would_edit = true)
          @redaction ||= begin
            target_status ||= current_site[:auto_publish] ? Zena::Status[:pub] : Zena::Status[:red]
            v = self.version
            if new_record? || !would_edit
              # nothing to do
              @version
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
        
        # Returns a lock (responds to 'user') for the specified lang or nil
        def lang_locked?(l = visitor.lang, v = self.version)
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
                errors.add_to_base "You cannot edit while you have a proposition waiting for approval."
              else
                errors.add_to_base "(#{l.user.login}) is editing this node"
              end
            end
          end
          
          def status_validation
            return true unless @redaction && @redaction.should_save?
            if t = current_transition
              errors.add_to_base("You do not have the rights to #{t[:name].to_s.gsub('_', ' ')}") unless transition_allowed?(t)
            else
              errors.add_to_base("This transition is not allowed.")
            end
          end
          
          def redaction_validation
            return true unless @redaction
            unless @redaction.valid?
              @redaction.errors.each do |attribute, message|
                attribute = "version_#{attribute}"
                errors.add(attribute, message) unless errors.on(attribute)
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
              @old_publication_to_remove = [version.class.fetch_ids("node_id = '#{self[:id]}' AND lang = '#{version[:lang]}' AND status = '#{Zena::Status[:pub]}' AND id != '#{version.id}'"), (version.status_was == Zena::Status[:rep] ? Zena::Status[:rem] : Zena::Status[:rep])]
            when :auto_publish
              # publication time might have changed
              if version.publish_from_changed?
                # we need to compute new
                self.publish_from = [get_publish_from, version.publish_from].min
              end
            when :update_attributes
              # nothing to do
            when :unpublish, :remove, :redit
              # moving down
              self.max_status = [get_max_status, version.status.to_i].max
            when :propose
              # moving up
              self.max_status = [max_status_was.to_i, version.status.to_i].max
            else
            end
            true
          end
          
          def multiversion_after_save
            if @redaction && @redaction.should_save?
              return false unless @redaction.save
            end
            @redaction = nil
            
            if @old_publication_to_remove
              self.class.connection.execute "UPDATE #{version.class.table_name} SET status = '#{@old_publication_to_remove[1]}' WHERE id IN (#{@old_publication_to_remove[0].join(', ')})" unless @old_publication_to_remove[0] == []
              
              res = after_publish
              
              # TODO: can we avoid this ? 
              # self.class.connection.execute "UPDATE #{self.class.table_name} SET updated_at = #{self.class.connection.quote(Time.now)} WHERE id=#{self[:id].to_i}" unless new_record?
            end
            @allowed_transitions       = nil
            @old_publication_to_remove = nil
            @redaction = nil
            true
          end
        
          def update_attribute_without_fuss(att, value)
            self[att] = value
            if value.kind_of?(Time)
              value = value.strftime("'%Y-%m-%d %H:%M:%S'")
            elsif value.nil?
              value = "NULL"
            else
              value = "'#{value}'"
            end
            self.class.connection.execute "UPDATE #{self.class.table_name} SET #{att}=#{value} WHERE id=#{self[:id]}"
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
      end
      
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
      end
    end
  end
end