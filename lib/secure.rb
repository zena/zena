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
      # * members of +read_group+ if the node is published and the current date is greater or equal to the publication date
      # * members of +publish_group+ if +max_status+ >= prop
      def secure_scope(visitor_id, visitor_groups)
        if visitor_id == 2
          '1'
        else
          "user_id = '#{visitor_id}' OR "+
          "(rgroup_id IN (#{visitor_groups.join(',')}) AND publish_from <= now() ) OR " +
          "(pgroup_id IN (#{visitor_groups.join(',')}) AND max_status > #{Zena::Status[:red]})"
        end
      end

      # Secure scope for write access.
      # [write]
      # * super user
      # * owner
      # * members of +write_group+ if node is published and the current date is greater or equal to the publication date
      def secure_write_scope(visitor_id, visitor_groups)
        if visitor_id == 2
          '1'
        else
          "user_id = '#{visitor_id}' OR "+
          "(wgroup_id IN (#{visitor_groups.join(',')}) AND publish_from <= now())"
        end
      end
      
      # Secure scope for publish or management access.
      # [publish]
      # * super user
      # * members of +publish_group+ if +max_status+ >= prop
      # * owner if member of +publish_group+ or private
      # 
      # [manage]
      # * owner if +max_status+ <= red
      # * owner if private
      def secure_drive_scope(visitor_id, visitor_groups)
        if visitor_id == 2
          '1'
        else
          "(user_id = '#{visitor_id}' AND "+
            "( (rgroup_id = 0 AND wgroup_id = 0 AND pgroup_id = 0) OR max_status <= #{Zena::Status[:red]} OR pgroup_id IN (#{visitor_groups.join(',')}) )" +
          ") OR "+
          "( pgroup_id IN (#{visitor_groups.join(',')}) AND max_status > #{Zena::Status[:red]} )"
        end
      end
    end
    
=begin rdoc
== Secure model
Read, write and publication access to an node is defined with four elements: one user and three groups.
link://rwp_groups.png

=== Definitions :
[inherit]  Defines how the groups propagate. If +inherit+ is set to '1', the node inherits rwp groups from it's reference. If
           +inherit+ is set to '0', the node has custom rwp groups. When set to '-1', the node is becomes private and all
           rwp groups are set to '0'.
[read]
    This means that the node can be seen.
[write]
    This means that new versions can be proposed for the node as well as new
    sub-pages, documents, events, etc. Basically can write = can add content. If a user has write access to
    a #Tag, this means he can add nodes to this #Tag (#Tag available as a category for other nodes).
[publish]
    This means that the content viewed by all can be altered by 
    1. publishing new versions
    2. changing the node itself (name, groups, location, categories, etc)
    3. removing the node and/or sub-nodes
    4. people with this access can see nodes that are not published yet
[manage]
    This is for nodes that <em>have not yet been published</em> or for <em>private nodes</em>
    A. <em>private node</em>
    1. can 'publish' node (it is not really published as the node is private...)
    2. can 'unpublish' (make this node a 'not published yet')
    3. can change node itself (cannot change groups)
    4. can destroy
    B. <em>node not published yet</em> only :
    5. make an node private (sets all groups to 0) or revert node to default groups (same as parent or project) if node not published yet
    5. can see node (edition = personal redaction or latest version)
[max_status]
    This is set to the highest status of all versions. Order from highest to lowest are : 'pub', 'prop', 'red', 'rep', 'rem', 'del'

=== Who can do what
[read]
* super user
* owner
* members of +read_group+ if the node is published and the current date is greater or equal to the publication date
* members of +publish_group+ if +max_status+ >= prop
  
[write]
* super user
* owner
* members of +write_group+ if node is published and the current date is greater or equal to the publication date
  
[publish]
* super user
* members of +publish_group+ if +max_status+ >= prop
* owner if member of +publish_group+

[manage]
* owner if +max_status+ <= red
* owner if private

=== Misc

* A user can only set a group in which he/she belongs.
* Only people from the 'admin' group can change an node's owner.
* Setting all groups to _public_ transforms the node into a wiki.
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
          belongs_to :rgroup, :class_name=>'Group', :foreign_key=>'rgroup_id'
          belongs_to :wgroup, :class_name=>'Group', :foreign_key=>'wgroup_id'
          belongs_to :pgroup, :class_name=>'Group', :foreign_key=>'pgroup_id'
          belongs_to :user
          before_validation :secure_before_validation
          after_save :check_inheritance
          before_destroy :secure_on_destroy
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
        def set_visitor(visitor_id, visitor_groups, user_lang)
          @visitor_id = visitor_id
          @visitor_groups = visitor_groups
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
            :create => { :user_id => @visitor_id, :lang => @visitor_lang }, 
            :find   => { :conditions => scope }) do
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
    
        # Return true if the node is considered as private (+read_group+, +write_group+ and +publish_group+ are +0+)
        def private?
          (rgroup_id==0 && wgroup_id==0 && pgroup_id==0)
        end
        
        # Return true if the node can be viewed by all (public)
        def public?
          can_read?(1,[1])
        end
  
        # people who can read:
        # * super user
        # * owner
        # * members of +read_group+ if the node is published and the current date is greater or equal to the publication date
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
        
        # people who can make visible changes
        # * super user
        # * members of +publish_group+
        def can_visible?(uid=visitor_id, ugps=visitor_groups)
          ( uid == 2 ) ||
          ( ugps.include?(pgroup_id) ) ||
          ( private? && ugps.include?(ref.pgroup_id))
        end
  
        # people who can manage:
        # * owner if +max_status+ <= red
        # * owner if private
        def can_manage?(uid=visitor_id)
          ( uid == 2 ) ||
          ( publish_from == nil && uid == user_id && max_status <= Zena::Status[:red] ) ||
          ( private? && uid == user_id )
        end
        
        # can change position, name, rwp groups, etc
        def can_drive?
          can_manage? || can_visible?
        end
        
        def secure_before_validation
          if new_record?
            secure_on_create
          else
            secure_on_update
          end
        end
        
        # 0. set node.user_id = visitor_id
        # 1. validate the presence of a valid project (one in which the visitor has write access and project<>self !)
        # 2. validate the presence of a valid reference (project or parent) (in which the visitor has write access and ref<>self !)
        # 3. validate +publish_group+ value (same as parent or ref.can_visible? and valid)
        # 4. validate +rw groups+ :
        #     a. if can_visible? : valid groups
        #     b. else inherit or private
        # 5. validate the rest
        def secure_on_create
          # set kpath
          self[:kpath] = self.class.kpath
          
          unless @visitor_id
            errors.add('base', "record not secured") 
            return false
          end
          self[:user_id] = visitor_id
          # validate reference
          
          if ref == nil
            errors.add(ref_field, "invalid reference")
            return false
          end
          [:rgroup_id, :wgroup_id, :pgroup_id, :template].each do |sym|
            # not defined = inherit
            self[sym] ||= ref[sym]
            self[sym] = 0 if self[sym] == ''
          end
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
            self[:rgroup_id] = 0
            self[:wgroup_id] = 0
            self[:pgroup_id] = 0
          when 0
            if ref.can_visible?
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
        #     a. can change to 'inherit' if can_visible? or can_manage? and max_status < pub and does not have children
        #     b. can change to 'private' if can_manage?
        #     c. can change to 'custom' if can_visible?
        # 6. validate the rest
        def secure_on_update
          unless @visitor_id
            errors.add('base', "record not secured")
            return false
          end
          @old = nil # force reload of 'old'
          unless old
            # cannot change node if old not found
            errors.add('base', "you do not have the rights to do this")
            return false
          end
          if !( old.can_drive? )
            errors.add('base', "you do not have the rights to do this")
            return false
          end
          if user_id != old.user_id
            if visitor_groups.include?(2) # admin group
              # only admin can change owners
              begin
                User.find(user_id)
              rescue ActiveRecord::RecordNotFound
                errors.add('user_id', "unknown user")
              end
            else
              errors.add('user_id', "you cannot change this")
            end
          end
          return false unless errors.empty?
          # verify reference
          if ref == nil
            errors.add(ref_field, "invalid reference")
            return false
          end
          if self[ref_field] != old[ref_field]
            # reference changed
            begin
              if old.private? || old.publish_from == nil
                # node was not visible to others
                if self[ref_field] == self[:id] ||
                    ! secure_write(ref_class) { ref_class.find(self[ref_field])} || 
                    ! secure_write(ref_class) { ref_class.find(old[ref_field])}
                  errors.add(ref_field, "invalid reference") 
                  return false
                end
              else
                # node was visible, moves must be made with publish rights in both
                # source and destination
                if self[ref_field] == self[:id] ||
                    ! secure_drive(ref_class) { ref_class.find(self[ref_field])} || 
                    ! secure_drive(ref_class) { ref_class.find(old[ref_field])}
                  errors.add(ref_field, "invalid reference") 
                  return false
                end
              end
            rescue ActiveRecord::RecordNotFound
              errors.add(ref_field, "invalid reference")
              return false
            end
            # check circular references
            ref_ids  = [self[:id]]
            curr_ref = self[:parent_id]
            ok = true
            while true
              if ref_ids.include?(curr_ref) # detect loops
                ok = false
                break
              end
              ref_ids << curr_ref
              break if curr_ref == ZENA_ENV[:root_id]
              rows = self.class.connection.execute("SELECT #{ref_field} FROM #{self.class.table_name} WHERE id=#{curr_ref}")
              if rows.num_rows == 0
                errors.add(ref_field, "reference missing in reference hierarchy")
                raise ActiveRecord::RecordNotFound
              end
              curr_ref = rows.fetch_row[0].to_i
            end
            unless ok
              errors.add(ref_field, 'circular reference')
              return false
            end
          end
          # publish_from can only be set by the object itself by setting @publish_from
          self[:publish_from] = @publish_from || old.publish_from
          # same with proposed
          self[:max_status] = @max_status || old.max_status
          # verify groups
          [:rgroup_id, :wgroup_id, :pgroup_id].each do |sym|
            # set to 0 if nil or ''
            self[sym] = 0 if !self[sym] || self[sym] == ''
          end
          if self[:inherit] == 0 && pgroup_id == 0
            # if pgroup_id is set to 0 ==> make node private
            self[:inherit] = -1
          end  
          case inherit
          when 1
            # inherit
            unless inherit == old.inherit
              if old.can_visible? || ( old.can_manage? && (old.max_status_with_heirs < Zena::Status[:pub]) )
                [:rgroup_id, :wgroup_id, :pgroup_id, :template].each do |sym|
                  self[sym] = ref[sym]
                end
              else
                errors.add('inherit', "you cannot change this")
              end
            end
          when -1
            # make private, only if owner
            unless (inherit == old.inherit)
              if old.can_drive? && (user_id == visitor_id)
                [:rgroup_id, :wgroup_id, :pgroup_id].each do |sym|
                  self[sym] = 0
                end
              else
                errors.add('inherit', "you cannot change this")
              end
            end
          when 0
            if old.can_visible?
              if private?
                # ok (all groups are 0)
              else
                if rgroup_id != 0 && rgroup_id != old[:rgroup_id] && !visitor_groups.include?(rgroup_id)
                  errors.add('rgroup_id', "unknown group")
                end
                if wgroup_id != 0 && wgroup_id != old[:wgroup_id] && !visitor_groups.include?(wgroup_id)
                  errors.add('wgroup_id', "unknown group") 
                end
                if pgroup_id != 0 && pgroup_id != old[:pgroup_id] && !visitor_groups.include?(pgroup_id)
                  errors.add('pgroup_id', "unknown group")
                end
              end
            else
              # must be the same as old
              errors.add('inherit', "you cannot change this") unless inherit == old.inherit
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
        
        def secure_on_destroy
          unless old && old.can_drive?
            errors.add('base', "you do not have the rights to do this")
            return false
          else
            return true
          end
        rescue ActiveRecord::RecordNotFound
          errors.add('base', "you do not have the rights to do this")
          return false          
        end
        
        # Return the language used by this node.
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
        

        # Reference for inherited rights
        def ref
          if !@ref || (@ref.id != self[ref_field])
            # no ref or ref changed
            @ref = secure_write(ref_class) { ref_class.find(self[ref_field]) }
          end
          if self.new_record? || (:id == ref_field) || (self[:id] != @ref[:id] )
            # reference is accepted only if it is not the same as self or self is root (ref_field==:id set by Node)
            @ref.freeze
          else
            nil
          end
        rescue ActiveRecord::RecordNotFound
          nil
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
            # the current node, we can change it's children), so we skip validation
            h.save_with_validation(false)
            h.spread_inheritance
          end
        end
        
        # return the maximum status of the current node and all it's heirs. This is used to allow
        # inheritance change with 'manage' rights on private nodes
        def max_status_with_heirs(max=0)
          max = [max, max_status].max
          return max if max == Zena::Status[:pub]
          heirs.each do |h|
            max = [max, h.max_status_with_heirs(max)].max
            break if max == Zena::Status[:pub]
          end
          return max
        end
        
        private
        
        # Version of the node in DB (returns nil for new records)
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
          #                Node --> I           
          #       Note --> IN          Page --> NP
          #                    Document   Form   Project
          #                       NPD      NPF      NPP
          # So now, to get all Pages, your sql becomes : WHERE kpath LIKE 'NP%'
          # to get all Documents : WHERE kpath LIKE 'NPD%'
          # all pages withou Documents : WHERE kpath LIKE 'NP%' AND NOT LIKE 'NPD%'
          def kpath
            @@kpath[self] ||= if superclass == ActiveRecord::Base
              self.to_s[0..0]
            else
              superclass.kpath + ksel
            end
          end
          
          # kpath selector for the current class
          def ksel
            self.to_s[0..0]
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
            :create => { :visitor_id => visitor_id, :visitor_groups => visitor_groups, :visitor_lang => lang }, 
            :find   => { :conditions => scope }) do
            result = yield
            if result
              if result.kind_of? Array
                result.each {|r| r.set_visitor(visitor_id, visitor_groups, lang)}
              else
                # give the node some info on the current visitor. This lets security and lang info
                # propagate naturally through the nodes.
                result.set_visitor(visitor_id, visitor_groups, lang)
              end
              result
            else
              raise ActiveRecord::RecordNotFound
            end
          end
        end
        
        # secure find for read access.
        def secure(obj, &block)
          secure_with_scope(obj, secure_scope(visitor_id, visitor_groups), &block)
        end

        # secure find for write access.
        def secure_write(obj, &block)
          secure_with_scope(obj, secure_write_scope(visitor_id, visitor_groups), &block)
        end
        
        # secure find for publish (and manage) access.
        def secure_drive(obj, &block)
          secure_with_scope(obj, secure_drive_scope(visitor_id, visitor_groups), &block)
        end

        def set_session_with_user(user)
          if user
            session[:user] = {}
            session[:user][:id] = user.id
            session[:user][:groups] = user.group_ids
            session[:user][:fullname] = user.fullname
            session[:user][:initials] = user.initials
            session[:user][:lang] = user.lang != "" ? user.lang : ZENA_ENV[:default_lang]
            session[:user][:time_zone] = user.time_zone
            # set lang
            lang
          else
            session[:user] = nil
          end
        end

        def visitor_id
          if session && session[:user]
            session[:user][:id]
          else
            1 # anonymous user
          end
        end

        def visitor_groups
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
  # This exception handles all flagrant access violations or tentatives (like suppression of _su_ user)
  class AccessViolation < Exception
  end
end


ActiveRecord::Base.send :include, Zena::Acts::Secure
ActionController::Base.send :include, Zena::Acts::SecureController