module Zena
  module Acts
    
=begin rdoc


=== Actions :

[publish]
  If the visitor #can_manage? or #can_publish? he/she can publish the item if it's status is 'red', 'rem', 'rep' or 'prop'

=end
    module Multiversioned
      # this is called when the module is included into the 'base' module
      def self.included(base)
        # add all methods from the module "AddActsAsMethod" to the 'base' module
        base.extend AddActsAsMethod
      end
      module AddActsAsMethod
        def acts_as_multiversioned
          before_create :version # this makes sure we have a version before the element is saved
          before_create :set_on_create
          validate :check_redaction_errors
          after_save :save_version
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

        # PUT YOUR INSTANCE METHODS HERE
        
        
        # ACCESSORS
        
        # RW
        def title
          t = version ? version.title : ""
          if t && t != ""
            t
          else
            self[:name]
          end
        end
        
        def title=(str); set_redaction(:title, str); end
          
        def summary; version.summary; end
        def summary=(str); set_redaction(:summary, str); end
          
        def text; version.text; end
        def text=(str); set_redaction(:text, str); end
          
        def comment; version.comment; end
        def comment=(str); set_redaction(:comment, str); end
        
        # READ ONLY
        def new_redaction?; version.new_record?; end
        def v_text; version.text; end
        def v_summary; version.summary; end
        def v_lang; version.lang; end
        def v_status; version.status; end
        def v_user_id; version.user_id; end
        def v_author; version.author; end
        def v_updated_at; version.updated_at; end
        def v_id; version.id; end
        
        # VERSION
        
        def version=(v)
          if v.kind_of?(Version)
            @version = v
            # keep a trace of this operation in case the user 'edits' this version
            @version_selected = true
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
      
        # update an item's versioned attributes creating a new 'redaction' in necessary.
        # if no parameter is passed, this sets the current version to redaction for the current user and 
        # language, returning false if this operation is not permitted.
        def update_redaction(hash)
          if redaction
            if redaction.update_attributes(hash) && update_max_status
              true
            else
              errors.add('version', redaction.errors.map{|k,v| "#{k} #{v}"}.join(", "))
              false
            end
          else
            false
          end
        end
        
        # try to set the item's version to a redaction
        def edit!
          if redaction
            true
          else
            false
          end
        end
        
        def edit_preview(hash)
          redaction.attributes = hash
        end
        
        # return an array of language strings
        def traductions
          editions.map {|ed| ed.lang}
        end
        
        # can propose for validation
        def can_propose?
          version.status == Zena::Status[:red]
        end
        
        # can publish
        def can_publish_item?
          version.status < Zena::Status[:pub] && can_drive?
        end
        
        # can refuse a publication
        def can_refuse?
          version.status > Zena::Status[:red] && can_publish_item?
        end
        
        # can change position, name, rwp groups, etc
        def can_drive?
          can_publish? || can_manage?
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
          return false unless can_publish_item?
          old_versions = versions.find_all_by_status_and_lang(Zena::Status[:pub], version[:lang])
          case version.status
          when Zena::Status[:rep]
            new_status = Zena::Status[:rem]
          else
            new_status = Zena::Status[:rep]
          end
          version.publish_from = pub_time || self.publish_from || Time.now
          version.status = Zena::Status[:pub]
          if version.save
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
        
        def remove
          return false unless can_drive?
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
          puts "AFREM"
          true
        end
        
        # Set +publish_from+ to the minimum publication time of all editions
        def update_publish_from
          result = versions.find(:first, :conditions=>"status = #{Zena::Status[:pub]}", :order=>"publish_from ASC")
          # we cannot set publish_from directly with self[:publish_from] : a security measure in acts_as_secure#secure_on_update
          # only accepts the @publish_from (private attribute) style.
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
          true
        end
        
        private
        
        def update_attribute_without_fuss(att, value)
          self[att] = value
          value = value.strftime("%Y-%m-%d %H:%M:%S") if value.kind_of?(Time)
          self.class.connection.execute "UPDATE #{self.class.table_name} SET #{att}='#{value}' WHERE id=#{self[:id]}"
        end
        
        def redaction
          return @redaction if @redaction
          begin
            # is there a current redaction ?
            if @version_selected
              v = versions.find(:first, :conditions=>["status >= #{Zena::Status[:red]} AND status < #{Zena::Status[:pub]} AND lang=?", version.lang])
            else
              v = versions.find(:first, :conditions=>["status >= #{Zena::Status[:red]} AND status < #{Zena::Status[:pub]} AND lang=?", visitor_lang])
            end
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
            if ( @version_selected == true )
              # user selected a specific version, do not change lang
              @version_selected = false
            else
              v.lang = visitor_lang
            end
            v.item = self
          end
          if v && (v.user_id == visitor_id) && v.status == Zena::Status[:red]
            @redaction = @version = v
          else
            nil
          end
        end
        
        def set_redaction(key, value)
          if redaction
            redaction.send "#{key}=".to_sym, value
          else
            redaction_error(key, "could not be set (no redaction)")
            nil
          end
        end
        
        def redaction_error(field, message)
          @redaction_errors ||= []
          @redaction_errors << [field, message]
        end
        
        def check_redaction_errors
          if @redaction_errors
            @redaction_errors.each do |err|
              errors.add(*err)
            end
          end
        end
        
        # Return the current version. If @version was not set, this is a normal find or a new record. We have to find
        # a suitable edition :
        # * if new_record?, create a new redaction
        # * if the current user has a redaction or proposition, this is his default 'edition'
        # * find an edition for current lang
        # * find an edition in the reference lang for this item
        # * find the first publication
        # TODO optimise this code to have a single SQL call and use ORDER to get the right thing
        def version #:doc:
          if ! @version
            if new_record?
              @version = version_class.new
              @version.user_id = @visitor_id || nil
              @version.lang = @visitor_lang || nil
              @version.status = Zena::Status[:red]
              @version.item = self
            elsif can_drive?
              @version =  Version.find(:first,
                            :select=>"*, (lang = '#{visitor_lang.gsub(/[^\w]/,'')}') as lang_ok",
                            :conditions=>[ "((status >= ? AND user_id = ?) OR status > ?) and item_id = ?", 
                                            Zena::Status[:red], visitor_id, Zena::Status[:red], self[:id] ],
                            :order=>"lang_ok DESC, status ASC ")
              if !@version
                @version = versions.find(:first, :order=>'id DESC')
              end
            else
              @version =  Version.find(:first,
                            :select=>"*, (lang = '#{visitor_lang.gsub(/[^\w]/,'')}') as lang_ok",
                            :conditions=>[ "((status >= ? AND user_id = ?) OR status = ?) and item_id = ?", 
                                            Zena::Status[:red], visitor_id, Zena::Status[:pub], self[:id] ],
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
          if (@version && @version.new_record?) || @redaction
            unless @version.save
              errors.add("base", "#{version_class.to_s.downcase} could not be saved")
              false
            else
              true
            end
          end
        end
        
        def set_on_create
          self[:ref_lang] = visitor_lang
          @version.user_id = visitor_id
          @version.lang = visitor_lang
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