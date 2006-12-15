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
          before_validation_on_create :set_on_create # this makes sure we have a version before the element is validated
          validate          :valid_redaction
          after_save        :save_version
          after_save        :after_all
          private
          has_many :versions
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
            # there can only be one redaction/proposition per lang per item. Only the owner of the red can edit
            v = versions.find(:first, :conditions=>["status >= #{Zena::Status[:red]} AND status < #{Zena::Status[:pub]} AND lang=?", visitor_lang])
            v == nil || (v.status == Zena::Status[:red] && v.user_id == visitor_id)
          end 
        rescue ActiveRecord::RecordNotFound
          true
        end
        
        # try to set the item's version to a redaction
        def edit!
          if redaction
            true
          else
            false
          end
        end
        
        # return an array of language strings
        def traductions
          editions.map {|ed| ed.lang}
        end
        
        # can propose for validation
        def can_propose?
          version.status == Zena::Status[:red]
        end
        
        # people who can publish:
        # * people who #can_visible? if +status+ >= prop or owner
        # * people who #can_manage? if item is private
        def can_publish?
          version.status < Zena::Status[:pub] && 
          ( ( can_visible? && (version.status > Zena::Status[:red] || version.user_id == visitor_id) ) ||
            ( can_manage?  && private? )
          )
        end
        
        # can refuse a publication
        def can_refuse?
          version.status > Zena::Status[:red] && can_publish?
        end
        
        # Can remove publication
        def can_unpublish?
          can_drive? && 
          version.status == Zena::Status[:pub] &&
          ( (visitor_id == user_id) ||
            # not owner of the item, cannot unpublish if no edition left
            (Version.find(:first, :conditions=>["item_id = ? AND publish_from <= now() AND id <> ? AND status = ?", id, v_id, Zena::Status[:pub]]) != nil)
          )
        end
        
        # can destroy item ? (only logged in user can destroy)
        def can_destroy?
          can_drive? && (user_id != 1)
        end
        
        # Propose for publication
        def propose(prop_status=Zena::Status[:prop])
          if version.user_id == visitor_id
            version.status = prop_status
            version.save && after_propose && update_max_status
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
          old_versions = versions.find_all_by_status_and_lang(Zena::Status[:pub], version[:lang])
          case version.status
          when Zena::Status[:rep]
            new_status = Zena::Status[:rem]
          else
            new_status = Zena::Status[:rep]
          end
          version.publish_from = pub_time || self.publish_from || Time.now
          version.status = Zena::Status[:pub]
            Version.logger.info "SAVING VERSION"
          if version.save
              Version.logger.info "SAVING VERSION DONE"
            # only remove previous publications if save passed
            old_versions.each do |p|
              p.status = new_status
              p.save
            end
            after_publish(pub_time) && update_publish_from && update_max_status
          else
            false
          end
        end
        
        def unpublish
          return false unless can_unpublish?
          version.status = Zena::Status[:red]
          if version.save
            update_publish_from && update_max_status && after_remove
          else
            false
          end
        end
        
        def remove
          return false unless can_unpublish?
          version.status = Zena::Status[:rem]
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
          result  = versions.find(:first, :conditions=>"status = #{Zena::Status[:pub]}", :order=>"publish_from ASC")
          new_pub = result ? result[:publish_from] : nil
          if self[:publish_from] != new_pub
            update_attribute_without_fuss(:publish_from, new_pub)
          end
          true
        end
        
        # Set +publish_from+ to the minimum publication time of all editions
        def update_max_status
          result = versions.find(:first, :order=>"status DESC")
          # we cannot set status directly with self[:max_status] : a security measure in acts_as_secure#secure_on_update
          # only accepts the @max_status (private attribute) style.
          new_max = result ? result[:status] : nil
          if self[:max_status] != new_max
            update_attribute_without_fuss(:max_status, new_max)
          end
          # Callback triggered after any changed to an item
          after_all
        end
        
        # Update an item's attributes or the item's version/content attributes. If the hash contains only
        # :v_... or :c_... keys, then only the version will be saved
        def update_attributes(hash)
          redaction_only = true
          hash.each do |k,v|
            next if k.to_s == 'id' # just ignore 'id' (cannot be set but is often around)
            unless k.to_s =~ /^(v_|c_)/
              redaction_only = false
              break
            end
          end
          if redaction_only
            hash.each do |k,v|
              next if k.to_s == 'id' # just ignore 'id' (cannot be set but is often around)
              method_missing("#{k}=".to_sym, v)
            end
            valid_redaction
            if errors.empty?
              save_version && update_max_status
            end
          else
            super
          end
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
        
        def redaction
          return @redaction if @redaction
          begin
            # is there a current redaction ?
            v = versions.find(:first, :conditions=>["status >= #{Zena::Status[:red]} AND status < #{Zena::Status[:pub]} AND lang=?", visitor_lang])
          rescue ActiveRecord::RecordNotFound
            v = nil
          end
          if v == nil && (can_write? || new_record?)
            # create new redaction
            v = version.clone
            v.status = Zena::Status[:red]
            v.publish_from = nil
            v.comment = ''
            v.number = ''
            v.user_id = visitor_id
            v.lang = visitor_lang
            v[:content_id] = version[:content_id] || version[:id]
            v.item = self
          end
          if v && (v.user_id == visitor_id) && v.status == Zena::Status[:red]
            @redaction = @version = v
          else
            nil
          end
        end
        
        # Any attribute starting with 'v_' belongs to the 'version' or 'redaction'
        # Any attribute starting with 'c_' belongs to the 'version' or 'redaction' content
        def method_missing(meth, *args)
          if meth.to_s =~ /^(v_|c_)([\w_\?]+(=?))$/
            target = $1
            method = $2.to_sym
            mode   = $3
            if mode == '='
              # set
              unless recipient = redaction
                # remove trailing '='
                redaction_error(meth.to_s[0..-2], "could not be set (no redaction)")
                return
              end
              recipient = recipient.redaction_content if target == 'c_'
              # puts "SEND #{method.inspect} #{args.inspect} TO #{recipient.class}"
              recipient.send(method,*args)  
            else
              # read
              recipient = version
              recipient = recipient.content if target == 'c_'
              recipient.send(method,*args)
            end
          else
            super
          end
        end
        
        def redaction_error(field, message)
          @redaction_errors ||= []
          @redaction_errors << [field, message]
        end
        
        def valid_redaction
          if @version && !@version.valid?
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
          if @redaction_errors
            @redaction_errors.each do |k,v|
              errors.add(k,v)
            end
          end
        end
        
        # Return the current version. If @version was not set, this is a normal find or a new record. We have to find
        # a suitable edition :
        # * if new_record?, create a new redaction
        # * find user redaction or proposition in the current lang 
        # * find an edition for current lang
        # * find an edition in the reference lang for this item
        # * find the first publication
        def version #:doc:
          if ! @version
            if new_record?
              @version = version_class.new
              @version.user_id = @visitor_id || nil
              @version.lang = @visitor_lang || nil
              @version.status = Zena::Status[:red]
              @version.item = self
            elsif can_drive?
              # sees propositions
              lang = visitor_lang.gsub(/[^\w]/,'')
              @version =  Version.find(:first,
                            :select=>"*, (lang = '#{lang}') as lang_ok",
                            :conditions=>[ "((status >= ? AND user_id = ? AND lang = ?) OR status > ?) and item_id = ?", 
                                            Zena::Status[:red], visitor_id, lang, Zena::Status[:red], self[:id] ],
                            :order=>"lang_ok DESC, status ASC ")
              if !@version
                @version = versions.find(:first, :order=>'id DESC')
              end
            else
              # only own redactions and published versions
              lang = visitor_lang.gsub(/[^\w]/,'')
              @version =  Version.find(:first,
                            :select=>"*, (lang = '#{lang}') as lang_ok",
                            :conditions=>[ "((status >= ? AND user_id = ? AND lang = ?) OR status = ?) and item_id = ?", 
                                            Zena::Status[:red], visitor_id, lang, Zena::Status[:pub], self[:id] ],
                            :order=>"lang_ok DESC, status ASC, publish_from ASC")

            end
            @version.item = self # preload self as item in version
          end
          if @version.nil?
            raise Exception.exception("Item #{self[:id]} does not have any version !!")
          end
          @version
        end
        
        def version_class
          Version
        end
        
        def save_version
          @version.save if (@version && @version.new_record?) || @redaction
        end
        
        def set_on_create
          self[:ref_lang] = visitor_lang
          version.user_id = visitor_id
          version.lang = visitor_lang
          true
        end
        
        public
        module ClassMethods
          # PUT YOUR CLASS METHODS HERE
          
          # Find an item based on a version id
          def version(version_id)
            version = Version.find(version_id.to_i)
            item = self.find(version.item_id)
            item.version = version
            item.eval_with_visitor 'errors.add("base", "you do not have the rights to do this") unless version.status == 50 || can_drive? || version.user_id == visitor_id'
          end
        end
      end
    end
  end
end

ActiveRecord::Base.send :include, Zena::Acts::Multiversioned