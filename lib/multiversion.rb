module Zena
  module Acts
    module Multiversioned
      # this is called when the module is included into the 'base' module
      def self.included(base)
        # add all methods from the module "AddActsAsMethod" to the 'base' module
        base.extend AddActsAsMethod
      end
      module AddActsAsMethod
        def acts_as_multiversioned
          validate          :valid_redaction
          after_save        :save_version
          after_save        :after_all
          private
          has_many :versions, :order=>"number DESC"
          has_many :editions, :class_name=>"Version", :conditions=>"publish_from <= now() AND status = #{Zena::Status[:pub]}", :order=>'lang'
          public
          class_eval <<-END
            include Zena::Acts::Multiversioned::InstanceMethods
          END
        end
      end
      
      
      module InstanceMethods
        def self.included(aClass)
          aClass.extend ClassMethods
        end
        
        #def new_redaction?; version.new_record?; end
        
        # VERSION
        def version=(v)
          if v.kind_of?(Version)
            @version = v
          end
        end
        
        def can_edit?
          can_edit_lang?
        end
        
        def can_edit_lang?(lang=nil)
          return false if ! can_write?
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
        
        # try to set the node's version to a redaction
        def edit!(lang = nil)
          redaction(lang)
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
          trad.map! do |t|
            t.node = self # make sure relation is kept and we do not reload a node that is not secured
            t
          end
          trad == [] ? nil : trad
        end
        
        # can propose for validation
        def can_propose?
          version.status == Zena::Status[:red]
        end
        
        # people who can publish:
        # * people who #can_visible? if +status+ >= prop or owner
        # * people who #can_manage? if node is private
        def can_publish?
          version.status < Zena::Status[:pub] && 
          ( ( can_visible? && (version.status > Zena::Status[:red] || version.user_id == visitor[:id]) ) ||
            ( can_manage?  && private? )
          )
        end
        
        # Can refuse a publication. Same rights as can_publish? if the current version is a redaction.
        def can_refuse?
          version.status > Zena::Status[:red] && can_publish?
        end
        
        # Can remove publication
        def can_unpublish?(v=version)
          can_drive? && v.status == Zena::Status[:pub]
        end
        
        # can destroy node ? (only logged in user can destroy)
        def can_destroy?
          can_drive? && (user_id != 1) # not anonymous
        end
        
        # Propose for publication
        def propose(prop_status=Zena::Status[:prop])
          if version.user_id == visitor[:id]
            version.status = prop_status
            version.save && after_propose && update_max_status
          else
            false
          end
        end
        
        # Backup a redaction (create a new version)
        # TODO: test
        def backup
          if version.user_id == visitor[:id]
            version.status = Zena::Status[:rep]
            @redaction = nil
            if version.save
              redaction.save
              # new redaction created
            end
          else
            false
          end
        end
        
        # Refuse publication
        def refuse
          return false unless can_refuse?
          version.status = Zena::Status[:red]
          version.save && after_refuse && update_max_status
        end
        
        # publish if version status is : redaction, proposition, replaced or removed
        # if version to publish is 'rem' or 'red' or 'prop' : old publication => 'replaced'
        # if version to publish is 'rep' : old publication => 'removed'
        def publish(pub_time=nil)
          return false unless can_publish?
          old_ids = version.class.fetch_ids "node_id = '#{self[:id]}' AND lang = '#{version[:lang]}' AND status = '#{Zena::Status[:pub]}'"
          case version.status
          when Zena::Status[:rep]
            new_status = Zena::Status[:rem]
          else
            new_status = Zena::Status[:rep]
          end
          version.publish_from = pub_time || version.publish_from || Time.now.utc
          version.status = Zena::Status[:pub]
          if version.save
            # only remove previous publications if save passed
            
            connection.execute "UPDATE #{version.class.table_name} SET status = '#{new_status}' WHERE id IN (#{old_ids.join(', ')})" unless old_ids == []
            after_publish(pub_time) && update_publish_from && update_max_status
          else
            merge_version_errors
            false
          end
        end
        
        def unpublish
          return false unless can_unpublish?
          version.status = Zena::Status[:red]
          version.publish_from = nil
          if version.save
            update_publish_from && update_max_status && after_remove
          else
            false
          end
        end
        
        # A published version can be removed by the members of the publish group
        # A redaction can be removed by it's owner
        def remove
          unless can_unpublish? || (version.status < Zena::Status[:pub] && (version.user_id == visitor[:id]))
            return false
          end
          version.status = Zena::Status[:rem]
          if version.save
            update_publish_from && update_max_status && after_remove
          else
            false
          end
        end
        
        def redit
          return false unless can_edit?
          version.status = Zena::Status[:red]
          if version.save
            update_publish_from && update_max_status && after_remove
          else
            false
          end
        end
        
        # Call backs
        def after_propose
          true
        end
        def after_refuse
          true
        end
        def after_publish
          true
        end
        def after_remove
          true
        end
        def after_all
          true
        end
        
        # Set +publish_from+ to the minimum publication time of all editions
        def update_publish_from
          return true if self[:publish_from] == version[:publish_from] && version[:status] == Zena::Status[:pub]
          result  = versions.find(:first, :conditions=>"status = #{Zena::Status[:pub]}", :order=>"publish_from ASC")
          new_pub = result ? result[:publish_from] : nil
          if self[:publish_from] != new_pub
            update_attribute_without_fuss(:publish_from, new_pub)
          end
          true
        end
        
        # Set +publish_from+ to the minimum publication time of all editions
        def update_max_status(version = self.version)
          return true if version[:status] == max_status
          result = versions.find(:first, :order=>"status DESC")
          # we cannot set status directly with self[:max_status] : a security measure in acts_as_secure#secure_on_update
          # only accepts the @max_status (private attribute) style.
          new_max = result ? result[:status] : nil
          if self[:max_status] != new_max
            update_attribute_without_fuss(:max_status, new_max)
          end
          # Callback triggered after any changed to an node
          after_all
        end
        
        # Update an node's attributes or the node's version/content attributes. If the attributes contains only
        # :v_... or :c_... keys, then only the version will be saved. If the attributes does not contain any :v_... or :c_...
        # attributes, only the node is saved, without creating a new version.
        def update_attributes(new_attributes)
          redaction_attr = false
          node_attr      = false
          
          attributes = new_attributes.stringify_keys
          attributes = remove_attributes_protected_from_mass_assignment(attributes)
          attributes.each do |k,v|
            next if k.to_s == 'id' # just ignore 'id' (cannot be set but is often around)
            if k.to_s =~ /^(v_|c_)/
              redaction_attr = true
            else
              node_attr      = true
            end
            break if node_attr && redaction_attr
          end
          if redaction_attr
            return false unless edit!
          end
          unless node_attr
            attributes.each do |k,v|
              next if k.to_s == 'id' # just ignore 'id' (cannot be set but is often around)
              self.send("#{k}=".to_sym, v)
            end
            valid_redaction
            if errors.empty?
              save_version && update_max_status
            end
          else
            super
          end
        end
        
        # Return the current version. If @version was not set, this is a normal find or a new record. We have to find
        # a suitable edition :
        # * if new_record?, create a new redaction
        # * find user redaction or proposition in the current lang 
        # * find an edition for current lang
        # * find an edition in the reference lang for this node
        # * find the first publication
        def version(number=nil) #:doc:
          return @version if @version
          
          if number && !new_record? && can_drive?
            # TODO: test
            @version = versions.find_by_number(number)
          else
            if ! @version
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
                                              Zena::Status[:red], visitor[:id], lang, Zena::Status[:red], self[:id] ],
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
                                              Zena::Status[:red], visitor[:id], lang, Zena::Status[:pub], self[:id] ],
                              :order=>"lang_ok DESC, ref_ok DESC, status ASC, publish_from ASC")

              end
            end
            if @version.nil?
              raise Exception.new("#{self.class} #{self[:id]} does not have any version !!")
            end
          end  
          @version.node = self # preload self as node in version
          @version
        end
        
        private
        
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
        
        def redaction(lang = nil)
          return @redaction if @redaction && (lang.nil? || lang == @redaction.lang)
          if new_record?
            @redaction = version
          else
            begin
              # is there a current redaction ?
              v = versions.find(:first, :conditions=>["status >= #{Zena::Status[:red]} AND status < #{Zena::Status[:pub]} AND lang=?", (lang || visitor.lang)])
            rescue ActiveRecord::RecordNotFound
              v = nil
            end
            if v == nil && can_write?
              # create new redaction
              v = version.clone
              v.status = Zena::Status[:red]
              v.publish_from = v.created_at = nil
              v.comment = v.number = ''
              v.user_id = visitor[:id]
              v.lang = lang || visitor.lang
              v[:content_id] = version[:content_id] || version[:id]
              v.node = self
            end  
            v.node = self if v
            
            if v && (v.user_id == visitor[:id]) && v.status == Zena::Status[:red]
              @redaction = @version = v
            elsif v
              errors.add('base', "(#{v.author.login}) is editing this node")
              nil
            else
              errors.add('base', 'you do not have the rights to do this')
              nil
            end
          end
        end
        
        # Any attribute starting with 'v_' belongs to the 'version' or 'redaction'
        # Any attribute starting with 'c_' belongs to the 'version' or 'redaction' content
        def method_missing(meth, *args)
          if meth.to_s =~ /^(v_|c_)(([\w_\?]+)(=?))$/
            target = $1
            method = $2.to_sym
            value  = $3.to_sym
            mode   = $4
            if mode == '='
              # set
              unless recipient = redaction
                # remove trailing '='
                redaction_error(meth.to_s[0..-2], "could not be set (no redaction)")
                return
              end
              # TODO: test the value != stuff
              if target == 'c_' 
                if !new_record? || ( args[0].kind_of?(String) && recipient.content[value] == args[0] )
                  # do not force a new redaction = ignore
                else
                  recipient = recipient.redaction_content
                  recipient.send(method,*args) rescue nil # bad attribute
                end
              else
                recipient.send(method,*args) rescue nil # bad attribute
              end
            else
              # read
              recipient = version
              recipient = recipient.content if target == 'c_'
              recipient.send(method,*args) rescue nil # bad attribute
            end
          else
            super
          end
        end
        
        # Errors that occur while setting attributes from the form are recorded here.
        def redaction_error(field, message)
          @redaction_errors ||= []
          @redaction_errors << [field, message]
        end
        
        # Make sure the redaction is valid before we save anything.
        def valid_redaction
          if @version && !@version.valid?
            merge_version_errors
          end
          if @redaction_errors
            @redaction_errors.each do |k,v|
              errors.add(k,v)
            end
          end
        end
        
        def merge_version_errors
          unless @version.errors.empty?
            @version.errors.each do |k,v|
              if k.to_s =~ /^c_/
                key = k.to_s
              elsif k.to_s == 'base'
                key = 'base'
              else
                key = "v_#{k}"
              end
              errors.add(key, v)
            end
          end
        end
        
        def version_class
          Version
        end
        
        def save_version
          @version.save if (@version && @version.new_record?) || @redaction
        end
        
        def set_on_create
          # set kpath 
          self[:kpath]    = self.class.kpath
          self[:user_id]  = visitor[:id]
          self[:ref_lang] = visitor.lang
          version.user_id = visitor[:id]
          version.lang    = visitor.lang
          true
        end
        
        public
        module ClassMethods
          # PUT YOUR CLASS METHODS HERE
          
          # Find a node based on a version id
          def version(version_id)
            version = Version.find(version_id.to_i)
            node = self.find(version.node_id)
            node.version = version
            node.eval_with_visitor 'errors.add("base", "you do not have the rights to do this") unless version.status == 50 || can_drive? || version.user_id == visitor[:id]'
          end
        end
      end
    end
  end
end

ActiveRecord::Base.send :include, Zena::Acts::Multiversioned