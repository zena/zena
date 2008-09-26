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
          has_many :versions, :order=>"number DESC",  :dependent => :destroy
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
        
        # Try to set the node's version to a redaction. If lang is specified
        def edit!(lang = nil, publish_after_save = false)
          redaction(lang, publish_after_save)
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
        
        # Returns false is the current visitor does not have enough rights to perform the action.
        def can_apply?(method, v=version)
          return false if new_record?
          return true  if visitor.is_su?
          case method
          when :drive
            can_drive?
          when :propose, :backup
            v.user_id == visitor[:id] && v.status == Zena::Status[:red]
          when :refuse
            v.status > Zena::Status[:red] && can_apply?(:publish)
          when :publish
            v.status < Zena::Status[:pub] && 
            ( ( can_visible? && (v.status > Zena::Status[:red] || v.status == Zena::Status[:rep] || v.user_id == visitor[:id]) ) ||
              ( can_manage?  && private? )
            )
          when :unpublish
            can_drive? && v.status == Zena::Status[:pub]
          when :remove
            (can_drive? || v.user_id == visitor[:id] ) && v.status <= Zena::Status[:red] && v.status > Zena::Status[:rem]
          when :redit
            can_edit? && v.user_id == visitor[:id]
          when :edit
            can_edit?
          when :destroy_version
            # anonymous users cannot destroy
            can_drive? && v.status == Zena::Status[:rem] && !visitor.is_anon? && (self.versions.count > 1 || empty?)
          when :update_attributes
            can_write? # basic check, complete check is made for each attribute during validations
          end
        end
        
        # Gateway to all modifications of the node or it's versions.
        def apply(method, *args)
          unless can_apply?(method)
            errors.add('base', 'you do not have the rights to do this')
            return false
          end
          res = case method
          when :propose
            version.status = args[0] || Zena::Status[:prop]
            version.save && after_propose && update_max_status
          when :backup
            version.status = Zena::Status[:rep]
            @redaction = nil
            redaction.save if version.save
          when :refuse
            version.status = Zena::Status[:red]
            version.save && after_refuse && update_max_status
          when :publish
            pub_time = args[0]
            old_ids = version.class.fetch_ids "node_id = '#{self[:id]}' AND lang = '#{version[:lang]}' AND status = '#{Zena::Status[:pub]}'"
            case version.status
            when Zena::Status[:rep]
              new_status = Zena::Status[:rem]
            else
              new_status = Zena::Status[:rep]
            end
            pub_time = args[0]
            version.publish_from = pub_time || version.publish_from || Time.now
            version.status = Zena::Status[:pub]
            if version.save
              # only remove previous publications if save passed
              self.class.connection.execute "UPDATE #{version.class.table_name} SET status = '#{new_status}' WHERE id IN (#{old_ids.join(', ')})" unless old_ids == []
              res = after_publish(pub_time) && update_publish_from && update_max_status
              if res
                self.class.connection.execute "UPDATE #{self.class.table_name} SET updated_at = #{self.class.connection.quote(Time.now)} WHERE id=#{self[:id].to_i}" unless new_record?
              end
              res
            else
              merge_version_errors
              false
            end
          when :unpublish
            version.status = Zena::Status[:rem]
            if version.save
              update_publish_from && update_max_status && after_unpublish
            else
              false
            end
          when :remove
            version.status = Zena::Status[:rem]
            if version.save
              update_publish_from && update_max_status && after_remove
            else
              false
            end
          when :redit
            version.status = Zena::Status[:red]
            if version.save
              update_publish_from && update_max_status && after_redit
            else
              false
            end
          when :destroy_version
            if versions.count == 1
              version.destroy && self.destroy
            else
              version.destroy
            end
          when :update_attributes
            attributes = args[0].stringify_keys
            attributes = remove_attributes_protected_from_mass_assignment(attributes)
            attributes = remove_attributes_with_same_value(attributes)
            return true if attributes == {} # nothing to be done.
            do_update_attributes(attributes)
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
        def after_unpublish
          true
        end
        def after_redit
          true
        end
        def after_remove
          true
        end
        def after_all
          true
        end
        
        # Set +publish_from+ to the minimum publication time of all editions
        # TODO: OPTIMIZATION: "UPDATE nodes SET publish_from = (select versions.publish_from from versions WHERE nodes.id=versions.node_id and versions.status = 50 order by versions.publish_from DESC) WHERE id = #{id}"
        def update_publish_from
          return true if version[:status] == Zena::Status[:pub] && self[:publish_from] == version[:publish_from]
          pub_string  = (self.class.connection.select_one("select publish_from from #{version.class.table_name} WHERE node_id='#{self[:id]}' and status = #{Zena::Status[:pub]} order by publish_from DESC LIMIT 1") || {})['publish_from']
          pub_date    = ActiveRecord::ConnectionAdapters::Column.string_to_time(pub_string)
          if self[:publish_from] != pub_date
            self.class.connection.execute "UPDATE #{self.class.table_name} SET publish_from = #{pub_string ? "'#{pub_string}'" : 'NULL'} WHERE id = #{id}"
            self[:publish_from] = pub_date
          end
          true
        end
        
        # Set +max_status+ to the maximum status of all versions
        def update_max_status(version = self.version)
          if version[:status] == max_status
            after_all
            return true
          end
          vers_table = version.class.table_name
          node_table = self.class.table_name
          new_max    = self.class.connection.select_one("select #{vers_table}.status from #{vers_table} WHERE #{vers_table}.node_id='#{self[:id]}' order by #{vers_table}.status DESC LIMIT 1")['status']
          self.class.connection.execute "UPDATE #{node_table} SET max_status = '#{new_max}' WHERE #{node_table}.id = #{id}" if new_max != self[:max_status]
          self[:max_status] = new_max
          # After_save does not necesseraly trigger after_all when a 
          # redaction is created/updated : the node is not saved when modifications only alter the redaction.
          after_all
        end
        
        # Update an node's attributes or the node's version/content attributes. If the attributes contains only
        # :v_... or :c_... keys, then only the version will be saved. If the attributes does not contain any :v_... or :c_...
        # attributes, only the node is saved, without creating a new version.
        def update_attributes(new_attributes)
          apply(:update_attributes,new_attributes)
        end
        
        
        # Return only the attributes that have changed, returns all if the record is new.
        # FIXME: handle link=>{...} correctly
        def remove_attributes_with_same_value(new_attributes)
          res = {}
          new_attributes.each do |k,v|
            if k == 'v_status'
              # makes no sense to remove this (it's used to auto publish changes)
              res[k] = v
              next
            end
            if safe_attribute?(k)
              current_value = self.send(k) rescue nil
            else
              # ignore
              next
            end
            
            case current_value.class.to_s
            when 'NilClass'
              res[k] = v unless v == nil || v == ''
            when 'String'
              res[k] = v unless current_value == v.to_s
            when 'Float'
              v = v.blank? ? nil : v.to_f
              res[k] = v unless current_value == v
            when 'Fixnum'
              v = v.blank? ? nil : v.to_i
              res[k] = v unless current_value == v
            when 'Date', 'DateTime', 'Time'
              begin
                res[k] = v unless current_value.strftime('%Y-%m-%d %H:%M:%S') == (v.kind_of?(String) ? DateTime.parse(v) : v).strftime('%Y-%m-%d %H:%M:%S')
              rescue
                res[k] = v
              end
            when 'TrueClass', 'FalseClass'
              res[k] = v unless current_value == v
            when 'File', 'StringIO'
              # md5 on content
              res[k] = v unless Digest::MD5.hexdigest(current_value.read) == Digest::MD5.hexdigest(v.read)
              v.rewind
              errors.clear # 'c_file' does an unparse_assets which can create errors.
            else
              res[k] = v
            end
          end
          res
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
        end
        
        def attributes=(attributes)
          super @attributes_filtering_done ? attributes : filter_attributes(attributes)
        end
        
        private
        
        def do_update_attributes(new_attributes)
          attributes = filter_attributes(new_attributes)
          
          publish_after_save = (attributes.delete('v_status').to_i == Zena::Status[:pub]) || current_site[:auto_publish]
          redaction_attr = false
          node_attr      = false
          
          attributes.each do |k,v|
            next if k.to_s == 'id' # just ignore 'id' (cannot be set but is often around)
            if k.to_s =~ /^(v_|c_|d_)/
              redaction_attr = true
            else
              node_attr      = true
            end
            break if node_attr && redaction_attr
          end
          
          if redaction_attr
            return false unless edit!(nil, publish_after_save)
          end
          
          if node_attr
            # super class call (original rails update_attributes)
            @attributes_filtering_done = true  # if anyone knows a better way to avoid filtering twice...
            self.attributes = attributes
            @attributes_filtering_done = false
            ok = save
          elsif attributes != {}
            attributes.each do |k,v|
              next if k.to_s == 'id' # just ignore 'id' (cannot be set but is often around)
              self.send("#{k}=".to_sym, v)
            end
            valid_redaction
            if errors.empty?
              ok = save_version
            end
            
            if ok
              # set updated at date
              update_attribute_without_fuss(:updated_at, Time.now)
            end
          else
            # nothing to update (only v_status)
            ok = true
          end
          
          if ok && publish_after_save
            if can_apply?(:publish)
              ok = apply(:publish)
            elsif can_apply?(:propose)
              ok = apply(:propose)
            end
          elsif ok
            ok = update_max_status && update_publish_from
          end
          ok
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

        # Find/create a redaction. If lang is specified, use it instead of the visitor's current language. If
        # publish_after_save is true and the current published version is not older then the site's redit_time and
        # the visitor is the author of the publication, update the publication instead of creating a new version.
        def redaction(lang = nil, publish_after_save = false)
          return @redaction if @redaction && (lang.nil? || lang == @redaction.lang)
          redit = false
          if new_record?
            @redaction = version
          elsif version.lang == lang && version.status == Zena::Status[:red] && version.user_id == visitor[:id]
            @redaction = version
          else
            lang ||= visitor.lang
            # is there a current redaction ?
            v = versions.find(:first, :conditions=>["status >= #{Zena::Status[:red]} AND status < #{Zena::Status[:prop]} AND lang=?", lang])
            if v == nil && can_write?
              # create new redaction or redit current publication
              if publish_after_save && version[:status] >= Zena::Status[:prop] && version[:user_id] == visitor[:id] && version[:lang] == lang && (Time.now < version[:updated_at] + current_site[:redit_time].to_i)
                if can_visible? || (can_manage? && private?) || version[:status] == Zena::Status[:prop]
                  # re-edit publication
                  redit = true
                  v = version
                end
              end
              
              if v == nil
                # could not convert a publication into a redaction, new version
                v = version.clone
                v.status = Zena::Status[:red]
                v.publish_from = v.created_at = nil
                v.comment = v.number = ''
                v.user_id = visitor[:id]
                v.lang = lang
                v[:content_id] = version[:content_id] || version[:id]
              end
            end
            v.node = self if v
            
            if v && (v.user_id == visitor[:id]) && (v.status == Zena::Status[:red] || redit)
              @old_version = @version
              @redaction   = @version = v
            elsif v
              errors.add('base', "(#{v.user.login}) is editing this node")
              nil
            else
              errors.add('base', 'you do not have the rights to do this')
              nil
            end
          end
        end
        
        # Any attribute starting with 'v_' belongs to the 'version' or 'redaction'
        # Any attribute starting with 'c_' belongs to the 'version' or 'redaction' content
        # FIXME: performance: create methods on the fly so that next calls will not pass through 'method_missing'. #189.
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
          self.class.version_class
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
          version.lang    = visitor.lang if version.lang.blank?
          version[:status]= Zena::Status[:pub] if current_site[:auto_publish]
          version[:publish_from] ||= Time.now if version[:status] == Zena::Status[:pub]
          true
        end
        
        public
        module ClassMethods
          # PUT YOUR CLASS METHODS HERE
          
          # This is a callback from acts_as_multiversioned
          def version_class
            Version
          end
          
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