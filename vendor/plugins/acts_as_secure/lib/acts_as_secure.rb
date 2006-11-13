module Zena
  Status = {
    :pub  => 50,
    :prop => 40,
    :prop_with => 35,
    :red  => 30,
    :rep  => 20,
    :rem  => 10,
    :del  => 0,
  }.freeze
end
module Zena
  module Acts 
    module SecureScope
      
      # Secure scope for read access.
      # [read]
      # * super user
      # * owner
      # * members of +read_group+ if the item is published and the current date is greater or equal to the publication date
      # * members of +publish_group+ if +max_status+ >= prop
      def secure_scope(user_id, user_groups)
        if user_id == 2
          '1'
        else
          "user_id = '#{user_id}' OR "+
          "(rgroup_id IN (#{user_groups.join(',')}) AND publish_from <= now() ) OR " +
          "(pgroup_id IN (#{user_groups.join(',')}) AND max_status > #{Zena::Status[:red]})"
        end
      end

      # Secure scope for write access.
      # [write]
      # * super user
      # * owner
      # * members of +write_group+ if item is published and the current date is greater or equal to the publication date
      def secure_write_scope(user_id, user_groups)
        if user_id == 2
          '1'
        else
          "user_id = '#{user_id}' OR "+
          "(wgroup_id IN (#{user_groups.join(',')}) AND publish_from <= now())"
        end
      end
      
      # Secure scope for publish or management access.
      # [publish]
      # * super user
      # * members of +publish_group+ if +max_status+ >= prop
      # * owner if member of +publish_group+
      # 
      # [manage]
      # * owner if +max_status+ <= red
      # * owner if private
      def secure_drive_scope(user_id, user_groups)
        if user_id == 2
          '1'
        else
          "(user_id = '#{user_id}' AND "+
            "( (rgroup_id = 0 AND wgroup_id = 0 AND pgroup_id = 0) OR max_status <= #{Zena::Status[:red]} OR pgroup_id IN (#{user_groups.join(',')}) )" +
          ") OR "+
          "( pgroup_id IN (#{user_groups.join(',')}) AND max_status > #{Zena::Status[:red]} )"
        end
      end
    end
    
=begin rdoc
== Secure model
Read, write and publication access to an item is defined with four elements: one user and three groups.
link://rwp_groups.png

=== Definitions :
[inherit]  Defines how the groups propagate. If +inherit+ is set to '1', the item inherits rwp groups from it's reference. If
           +inherit+ is set to '0', the item has custom rwp groups. When setting it to '-1', the groups are set to 0 and
           +inherit+ is then set to '0' : this is a shortcut to make an item private.
[read]
		This means that the item can be seen.
[write]
		This means that new versions can be proposed for the item as well as new
		sub-pages, documents, events, etc. Basically can write = can add content. If a user has write access to
		a #Tag, this means he can add items to this #Tag (#Tag available as a category for other items).
[publish]
		This means that the content viewed by all can be altered by 
		1. publishing new versions
		2. changing the item itself (name, groups, location, categories, etc)
		3. removing the item and/or sub-items
		4. people with this access can see items that are not published yet
[manage]
		This is for items that <em>have not yet been published</em> or for <em>private items</em>
		A. <em>private item</em>
		1. can 'publish' item (it is not really published as the item is private...)
		2. can 'unpublish' (make this item a 'not published yet')
		3. can change item itself (cannot change groups)
		4. can destroy
		B. <em>item not published yet</em> only :
		5. make an item private (sets all groups to 0) or revert item to default groups (same as parent or project)
		5. can see item (edition = personal redaction or latest version)
[max_status]
    This is set to the highest status of all versions. Order from highest to lowest are : 'pub', 'prop', 'red', 'rep', 'rem', 'del'

=== Who can do what
[read]
* super user
* owner
* members of +read_group+ if the item is published and the current date is greater or equal to the publication date
* members of +publish_group+ if +max_status+ >= prop
  
[write]
* super user
* owner
* members of +write_group+ if item is published and the current date is greater or equal to the publication date
  
[publish]
* super user
* members of +publish_group+ if +max_status+ >= prop
* owner if member of +publish_group+

[manage]
* owner if +max_status+ <= red
* owner if private

=== Misc

* A user can only set a group in which he/she belongs.
* Only people from the 'admin' group can change an item's owner.
* Setting all groups to _public_ transforms the item into a wiki.
* A user who belongs to the 'admin' group (id=2), automatically belongs to all other groups.

=== Usage

In the controller :
  require 'lib/acts_as_secure'
  class PagesController < ApplicationController
    before_filter :set_logged_in_user
    acts_as_secure_controller

    def show
      @page = secure { Page.find(params[:id]) }
    end
    private
    def set_logged_in_user
      # .. get user
      set_session_with_user @user
  end

In the model :
  require 'lib/acts_as_secure'
  class Page < ActiveRecord::Base
    acts_as_secure
  end

In the helpers (if you intend to use secure find there...)
  require 'lib/acts_as_secure'
	module ApplicationHelper
	  include Zena::Acts::SecureScope
	  include Zena::Acts::SecureController::InstanceMethods
	  # ...
	end
Just doing the above will filter all result according to the logged in user.
=end
    module Secure
      include SecureScope
      # this is called when the module is included into the 'base' module
      def self.included(base)
        # add all methods from the module "AddActsAsMethod" to the 'base' module
        base.extend AddActsAsMethod
      end
      module AddActsAsMethod
        def acts_as_secure
          belongs_to :read_group, :class_name=>'Group', :foreign_key=>'rgroup_id'
          belongs_to :write_group, :class_name=>'Group', :foreign_key=>'wgroup_id'
          belongs_to :publish_group, :class_name=>'Group', :foreign_key=>'pgroup_id'
          belongs_to :user
          validate_on_create :secure_on_create
          validate_on_update :secure_on_update
          after_save :check_inheritance
          class_eval <<-END         
            include Zena::Acts::Secure::InstanceMethods
          END
        end
      end
      
      
      module InstanceMethods
        attr_accessor :visitor_id, :visitor_groups, :visitor_lang
        
        def self.included(base)
          base.extend ClassMethods
        end
          
        # Store visitor to produce scope when needed and to retrieve correct editions.
        def set_visitor(user_id, user_groups, user_lang)
          @visitor_id = user_id
          @visitor_groups = user_groups
          @visitor_lang = user_lang
          # callback used by functions triggered before 'set_visitor'
          if @eval_on_visitor
            @eval_on_visitor.each do |str|
              eval(str)
            end
            if errors.empty?
            else
              raise ActiveRecord::RecordNotFound
            end
          end
          self
        end
        
        # list of callbacks to trigger when set_visitor is called
        def eval_with_visitor(str)
          @eval_on_visitor ||= []
          @eval_on_visitor << str
          self
        end
  
        # Secure used by the object itself (to find children, etc). This scope uses @visitor_id, @visitor_groups and @visitor_lang
        # as set by #set_visitor
        def secure_with_scope(obj, scope)
          obj.with_scope(
            :create => { :visitor_id => @visitor_id, :visitor_groups => @visitor_groups, :visitor_lang => @visitor_lang }, 
            :find=>{ :conditions => scope }) do
            result = yield
            if result
              # propagate secure scope to children
              if result.kind_of? Array
                result.each {|r| r.set_visitor(@visitor_id || 1, @visitor_groups || [1], @visitor_lang)}
              else
                result.set_visitor(@visitor_id || 1, @visitor_groups || [1], @visitor_lang)
              end
              result
            else
              raise ActiveRecord::RecordNotFound
            end
          end
        end
        
        # secure for read access used by the object itself
        def secure(obj, &block)
          secure_with_scope(obj,secure_scope(visitor_id, visitor_groups), &block)
        end
  
        # secure for write access used by the object itself
        def secure_write(obj, &block)
          secure_with_scope(obj,secure_write_scope(visitor_id, visitor_groups), &block)
        end
        
        # secure for publish access used by the object itself
        def secure_drive(obj, &block)
          secure_with_scope(obj,secure_drive_scope(visitor_id, visitor_groups), &block)
        end
    
        # Return true if the item is considered as private (+read_group+, +write_group+ and +publish_group+ are +0+)
        def private?
          (rgroup_id==0 && wgroup_id==0 && pgroup_id==0)
        end
        
        # Return true if the item can be viewed by all (public)
        def public?
          can_read?(1,[1])
        end
  
        # people who can read:
        # * super user
        # * owner
        # * members of +read_group+ if the item is published and the current date is greater or equal to the publication date
        # * members of +publish_group+ if +max_status+ >= prop
        def can_read?(uid=visitor_id, ugps=visitor_groups)
          ( uid == 2 ) ||
          ( uid == user_id ) ||
          ( ugps.include?(rgroup_id) && publish_from && Time.now >= publish_from ) ||
          ( ugps.include?(pgroup_id) && max_status > Zena::Status[:red] )
        end
  
        # people who can write:
        # * super user
        # * owner
        # * members of +write_group+ if published and the current date is greater or equal to the publication date
        def can_write?(uid=visitor_id, ugps=visitor_groups)
          ( uid == 2 ) ||
          ( uid == user_id ) ||
          ( ugps.include?(wgroup_id) && publish_from && Time.now >= publish_from )
        end
  
        # people who can publish:
        # * super user
        # * members of +publish_group+ if +max_status+ >= prop
        # * owner if member of +publish_group+
        def can_publish?(uid=visitor_id, ugps=visitor_groups)
          ( uid == 2 ) ||
          ( ugps.include?(pgroup_id) && (max_status > Zena::Status[:red] || uid == user_id) )
        end
  
        # people who can manage:
        # * owner if +max_status+ <= red
        # * owner if private
        def can_manage?(uid=visitor_id)
          ( uid == 2 ) ||
          ( publish_from == nil && uid == user_id && max_status <= Zena::Status[:red] ) ||
          ( private? && uid == user_id )
        end
        
        # 0. set item.user_id = visitor_id
        # 1. validate the presence of a valid project (one in which the visitor has write access and project<>self !)
        # 2. validate the presence of a valid reference (project or parent) (in which the visitor has write access and ref<>self !)
        # 3. validate +publish_group+ value (same as parent or ref.can_publish? and valid)
        # 4. validate +rw groups+ :
        #     a. if can_publish? : valid groups
        #     b. else (can_manage as item is new) : rgroup_id = 0 => inherit, rgroup_id = -1 => private else error.
        # 5. validate the rest
        def secure_on_create
          self.class.logger.info "SECURE CALLBACK ON CREATE"
          # set kpath
          self[:kpath] = self.class.kpath
          
          unless @visitor_id
            errors.add('base', "record not secured") 
            return
          end
          self[:user_id] = visitor_id
          # validate reference
          if ref == nil
            errors.add(ref_field, "invalid reference") 
            return
          end
          # nil = inherit
          self[:rgroup_id] ||= ref[:rgroup_id]
          self[:wgroup_id] ||= ref[:wgroup_id]
          self[:pgroup_id] ||= ref[:pgroup_id]
          self[:template ] ||= ref[:template ]
          if inherit.nil?
            if rgroup_id == ref.rgroup_id && wgroup_id == ref.wgroup_id && pgroup_id == ref.pgroup_id
              self[:inherit  ] = 1
            else
              self[:inherit  ] = 0
            end
          end
          case inherit
          when 1
            # force inheritance
            self[:rgroup_id] = ref.rgroup_id
            self[:wgroup_id] = ref.wgroup_id
            self[:pgroup_id] = ref.pgroup_id
            self[:template ] = ref.template
          when -1
            # private
            self[:inherit  ] = 0
            self[:rgroup_id] = 0
            self[:wgroup_id] = 0
            self[:pgroup_id] = 0
          when 0
            if ref.can_publish?
              errors.add('rgroup_id', "unknown group") unless visitor_groups.include?(rgroup_id)
              errors.add('wgroup_id', "unknown group") unless visitor_groups.include?(wgroup_id)
              errors.add('pgroup_id', "unknown group") unless visitor_groups.include?(pgroup_id)
            elsif private?
              # ok
            else
              errors.add('inherit', "invalid value")
              errors.add('rgroup_id', "you cannot change this") unless rgroup_id == ref.rgroup_id
              errors.add('wgroup_id', "you cannot change this") unless wgroup_id == ref.wgroup_id
              errors.add('pgroup_id', "you cannot change this") unless pgroup_id == ref.pgroup_id
              errors.add('template' , "you cannot change this") unless template  == ref.template
            end
          else
            errors.add('inherit', "bad inheritance mode")
          end  
          errors.add('template', "unknown template '#{template}.rhtml'") unless File.exist?(File.join(RAILS_ROOT, 'app','views', 'templates', "#{template}.rhtml"))

          # publish_from can only be set by the object itself by setting @publish_from
          self[:publish_from] = @publish_from || nil
          # same for proposed
          self[:max_status] = @max_status || Zena::Status[:red]
          return errors.empty?
        end

        # 1. if pgroup changed from old, make sure user could do this and new group is valid
        # 2. if owner changed from old, make sure only a user in 'admin' can do this
        # 3. error if user cannot publish nor manage
        # 4. parent/project changed ? verify 'publish access to new *and* old'
        # 5. validate +rw groups+ :
        #     a. if can_publish? : valid groups
        #     b. else (can_manage as item is new) : rgroup_id = 0 => inherit, rgroup_id = -1 => private else error.
        # 6. validate the rest
        def secure_on_update
          self.class.logger.info "SECURE CALLBACK ON UPDATE"
          unless @visitor_id
            errors.add('base', "record not secured")
            return
          end
          unless old
            # cannot change item if old not found
            errors.add('base', "you do not have the rights to do this")
            return
          end
          if !( old.can_publish? || old.can_manage? )
            errors.add('base', "you do not have the rights to do this")
            return
          end
          if user_id != old.user_id
            if visitor_groups.include?(2) # admin group
              # only admin can change owners
              begin
                contact = secure_write(Contact) { Contact.find_by_address_id(user_id) }
                errors.add('user_id', "contact is not a user") unless contact.address.kind_of?(User)
              rescue ActiveRecord::RecordNotFound
                errors.add('user_id', "unknown contact")
              end
            else
              errors.add('user_id', "you cannot change this")
            end
          end
          return unless errors.empty?
          # verify reference
          if ref == nil
            errors.add(ref_field, "invalid reference")
            return
          end
          if self[ref_field] != old[ref_field]
            # reference changed
            begin
              if old.private? || old.publish_from == nil
                # item was not visible to others
                if self[ref_field] == self[:id] ||
                    ! secure_write(ref_class) { ref_class.find(self[ref_field])} || 
                    ! secure_write(ref_class) { ref_class.find(old[ref_field])}
                  errors.add(ref_field, "invalid reference") 
                  return
                end
              else
                # item was visible, moves must be made with publish rights in both
                # source and destination
                if self[ref_field] == self[:id] ||
                    ! secure_drive(ref_class) { ref_class.find(self[ref_field])} || 
                    ! secure_drive(ref_class) { ref_class.find(old[ref_field])}
                  errors.add(ref_field, "invalid reference") 
                  return
                end
              end
            rescue ActiveRecord::RecordNotFound
              errors.add(ref_field, "invalid reference")
              return
            end
          end
          # publish_from can only be set by the object itself by setting @publish_from
          self[:publish_from] = @publish_from || old.publish_from
          # same with proposed
          self[:max_status] = @max_status || old.max_status
          # verify groups
          if inherit == old.inherit && inherit == 1 && 
               (rgroup_id != ref.rgroup_id || wgroup_id != ref.wgroup_id || pgroup_id != ref.pgroup_id || template != ref.template)
            # set inherit if there is a change in rwg groups or template but inherit was not updated accordingly   
            self[:inherit] = 0
          end
          case inherit
          when 1
            errors.add('inherit', "you cannot change this") unless (inherit == old.inherit) || old.can_manage? || old.can_publish?
            self[:rgroup_id] = ref.rgroup_id
            self[:wgroup_id] = ref.wgroup_id
            self[:pgroup_id] = ref.pgroup_id
            self[:template ] = ref.template
          when -1
            # make private
            errors.add('inherit', "you cannot change this") unless old.can_manage? || old.can_publish?
            self[:inherit  ] = 0
            self[:rgroup_id] = 0
            self[:wgroup_id] = 0
            self[:pgroup_id] = 0
          when 0
            if old.can_publish?
              if private?
                # ok (all gruops are nil)
              else
                if (rgroup_id != old[:rgroup_id] && !visitor_groups.include?(rgroup_id))
                  errors.add('rgroup_id', "unknown group")
                end
                if (wgroup_id != old[:wgroup_id] && !visitor_groups.include?(wgroup_id))
                  errors.add('wgroup_id', "unknown group") 
                end
                if (pgroup_id != old[:pgroup_id] && !visitor_groups.include?(pgroup_id))
                  errors.add('pgroup_id', "unknown group")
                end
              end
            elsif old.can_manage? && private?
              # all groups are nil
            else
              # must be the same as old
              errors.add('inherit', "invalid value") unless inherit == old.inherit
              errors.add('rgroup_id', "you cannot change this") unless rgroup_id == old.rgroup_id
              errors.add('wgroup_id', "you cannot change this") unless wgroup_id == old.wgroup_id
              errors.add('pgroup_id', "you cannot change this") unless pgroup_id == old.pgroup_id
              errors.add('template', "you cannot change this") unless  template  == old.template
            end
          else
            errors.add('inherit', "bad inheritance mode")
          end  
          errors.add('template', "unknown template") unless template == old[:template] || File.exist?(File.join(RAILS_ROOT, 'app', 'views', 'templates', "#{template}.rhtml"))
          @needs_inheritance_spread = (rgroup_id != old.rgroup_id || wgroup_id != old.wgroup_id || pgroup_id != old.pgroup_id || template != old.template)        
          return errors.empty?
        end
        
        def before_destroy
          secure_on_destroy
        end
        
        def secure_on_destroy
          unless old.can_publish? || old.can_manage?
            errors.add('base', "you do not have the rights to do this")
            return false
          end
        rescue ActiveRecord::RecordNotFound
          errors.add('base', "you do not have the rights to do this")
          return false          
        end
        
        # Return the language used by this item.
        def visitor_lang
          @visitor_lang || ref_lang
        end
  
        # Return the current visitor id or 'anonymous' if it is not set.
        def visitor_id
          @visitor_id || 1
        end
  
        # Return the current visitor's groups or 'public' if nothing set.
        def visitor_groups
          @visitor_groups || [1]
        end
        
        
        protected
        
        def check_inheritance
          if @needs_inheritance_spread
            spread_inheritance
          end
          true
        end
        
        # When the rwp groups are changed, spread this change to the 'children' with
        # inheritance mode set to '1'.
        def spread_inheritance
          heirs.each do |h|
            h[:rgroup_id] = rgroup_id
            h[:wgroup_id] = wgroup_id
            h[:pgroup_id] = pgroup_id
            h[:template ] = template
            # there should never be errors here (if we had the correct rights to change
            # the current item, we can change it's children), so we skip validation
            h.save_with_validation(false)
            h.spread_inheritance
          end
        end
        
        private
        
        # Version of the item in DB (returns nil for new records)
        def old
          if new_record?
            nil
          else
            begin
              @old ||= secure_drive(self.class) { self.class.find(self[:id]) }
            rescue ActiveRecord::RecordNotFound
              nil
            end
          end
        end

        # Reference for inherited rights
        def ref
          if !@ref || (@ref.id != self[ref_field])
            # no ref or ref changed
            @ref = secure_write(ref_class) { ref_class.find(self[ref_field]) }
          end
          if self.new_record? || (:id == ref_field) || (self[:id] != @ref[:id] )
            # reference is accepted only if it is not the same as self or self is root (ref_field==:id set by Item)
            @ref
          else
            nil
          end
        rescue ActiveRecord::RecordNotFound
          nil
        end
        
        # List of elements using the current element as a reference. Used to update
        # the rwp groups if they inherit from the reference. Can be overwritten by sub-classes.
        def heirs
          base_class.find(:all, :conditions=>["#{ref_field} = ? AND inherit='1'" , self[:id] ] ) || []
        end
        
        # Reference class. Must be overwritten by sub-classes.
        def ref_class
          self.class
        end
        
        # Must be overwritten.
        def base_class
          self.class
        end
        # Reference foreign_key. Can be overwritten by sub-classes.
        def ref_field
          :reference_id
        end

        public         
        # helper for testing validations
        def show_errors
          errors.each {|k,m| puts "[#{k}] #{m}"}
        end
        module ClassMethods
          # kpath is a class shortcut to avoid tons of 'OR type = Page OR type = Document'
          # we build this path with the first letter of each class. The example bellow
          # shows how the kpath is built:
          #           class hierarchy
          #                Item --> I           
          #       Note --> IN          Page --> IP
          #                    Document   Form   Project
          #                       IPD      IPF      IPP
          # So now, to get all Pages, your sql becomes : WHERE kpath LIKE 'IP%'
          # to get all Documents : WHERE kpath LIKE 'IPD%'
          # all pages withou Documents : WHERE kpath LIKE 'IP%' AND NOT LIKE 'IPD%'
          def kpath
            @@kpath[self] ||= if superclass == ActiveRecord::Base
              self.to_s[0..0]
            else
              superclass.kpath + self.to_s[0..0]
            end
          end

          @@kpath = {}

          # Replace Rails subclasses normal behavior
          def type_condition
            " #{table_name}.kpath LIKE '#{kpath}%' "
          end
          
          # Replace Rails subclasses normal behavior
          def type_condition
            " #{table_name}.kpath LIKE '#{kpath}%' "
          end
        end
      end
    end
    
    # ============================================= SECURE CONTROLLER ===============
    module SecureController
      include SecureScope
      # this is called when the module is included into the 'base' module
      def self.included(base)
        # add all methods from the module "AddActsAsMethod" to the 'base' module
        base.extend AddActsAsMethod
      end
      module AddActsAsMethod
        def acts_as_secure_controller
          helper_method :lang

          class_eval <<-END
            include Zena::Acts::SecureController::InstanceMethods
          END
        end
      end
      
      
      module InstanceMethods
        def self.included(base)
          base.extend ClassMethods
        end
        
        # these methods are not actions that can be called from the web !!
        private
        
        # get current lang
        def lang
          session[:lang] ||= session[:user] ? session[:user][:lang] : ZENA_ENV[:default_lang]
        end
        
        # secure find with scope (for read/write or publish access)
        def secure_with_scope(obj, scope)
          obj.with_scope(
            :create => { :visitor_id => user_id, :visitor_groups => user_groups, :visitor_lang => lang }, 
            :find   => { :conditions => scope }) do
            result = yield
            if result
              if result.kind_of? Array
                result.each {|r| r.set_visitor(user_id, user_groups, lang)}
              else
                # give the item some info on the current visitor. This lets security and lang info
                # propagate naturally through the items.
                result.set_visitor(user_id, user_groups, lang)
              end
              result
            else
              raise ActiveRecord::RecordNotFound
            end
          end
        end
        
        # secure find for read access.
        def secure(obj, &block)
          secure_with_scope(obj, secure_scope(user_id, user_groups), &block)
        end

        # secure find for write access.
        def secure_write(obj, &block)
          secure_with_scope(obj, secure_write_scope(user_id, user_groups), &block)
        end
        
        # secure find for publish (and manage) access.
        def secure_drive(obj, &block)
          secure_with_scope(obj, secure_drive_scope(user_id, user_groups), &block)
        end

        def set_session_with_user(user)
          if user
            session[:user] = {}
            session[:user][:id] = user.id
            session[:user][:groups] = user.group_ids
            session[:user][:fullname] = user.fullname
            session[:user][:lang] = user.lang != "" ? user.lang : ZENA_ENV[:default_lang]
            # set lang
            lang
          else
            session[:user] = nil
          end
        end

        def user_id
          if session && session[:user]
            session[:user][:id]
          else
            1 # anonymous user
          end
        end

        def user_groups
          if session && session[:user]
            session[:user][:groups]
          else
            [1] # public group
          end
        end
        
        module ClassMethods
          # PUT YOUR CLASS METHODS HERE (without self...)
        end
      end
    end
  end
end
# This exception handles all flagrant access violations or tentatives (like suppression of _su_ user)
class AccessViolation < Exception
end

ActiveRecord::Base.send :include, Zena::Acts::Secure
ActionController::Base.send :include, Zena::Acts::SecureController