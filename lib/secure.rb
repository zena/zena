module Zena
  # version status  
  Status = {
    :pub  => 50,
    :prop => 40,
    :prop_with => 35,
    :red_visible => 33,
    :red  => 30,
    :rep  => 20,
    :rem  => 10,
    :del  => 0,
  }.freeze
  
  module Acts 
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
    acts_as_secure

    def show
      @page = secure { Page.find(params[:id]) }
    end
    private
    def set_logged_in_user
      # .. get user
      session[:user] = @user[:id]
  end

#FIXME: correct doc.
In the model :
  require 'lib/acts_as_secure'
  class Page < ActiveRecord::Base
    acts_as_secure_node
  end

In the helpers (if you intend to use secure find there...)
  require 'lib/acts_as_secure'
  module ApplicationHelper
    include Zena::Acts::Secure
    # ...
  end
Just doing the above will filter all result according to the logged in user.
=end
    module SecureNode
      # this is called when the module is included into the 'base' module
      def self.included(base)
        # add all methods from the module "AddActsAsMethod" to the 'base' module
        base.extend AddActsAsMethod
      end
      module AddActsAsMethod
        def acts_as_secure_node
          belongs_to :rgroup, :class_name=>'Group', :foreign_key=>'rgroup_id'
          belongs_to :wgroup, :class_name=>'Group', :foreign_key=>'wgroup_id'
          belongs_to :pgroup, :class_name=>'Group', :foreign_key=>'pgroup_id'
          belongs_to :user
          before_validation :secure_before_validation
          after_save :check_inheritance
          before_destroy :secure_on_destroy
          class_eval <<-END
            include Zena::Acts::SecureNode::InstanceMethods
          END
        end
      end
      
      
      module InstanceMethods
        
        def self.included(base)
          base.extend ClassMethods
        end
          
        # Store visitor to produce scope when needed and to retrieve correct editions.
        def visitor=(visitor)
          @visitor = visitor
          if new_record?
            set_on_create
          end
          # callback used by functions triggered before 'visitor='
          if @eval_on_visitor
            @eval_on_visitor.each do |str|
              eval(str)
            end
            unless errors.empty?
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
    
        # Return true if the node is considered as private (+read_group+, +write_group+ and +publish_group+ are +0+)
        def private?
          (rgroup_id==0 && wgroup_id==0 && pgroup_id==0)
        end
        
        # Return true if the node can be viewed by all (public)
        def public?
          can_read?(visitor.site.anon,visitor.site.anon.group_ids) # visible by anonymous
        end
  
        # people who can read:
        # * super user
        # * owner
        # * members of +read_group+ if the node is published and the current date is greater or equal to the publication date
        # * members of +publish_group+ if +max_status+ >= prop
        def can_read?(vis = visitor, ugps=visitor.group_ids)
          ( vis.is_su? ) || # super user
          ( vis[:id] == user_id ) ||
          ( ugps.include?(rgroup_id) && publish_from && Time.now >= publish_from ) ||
          ( ugps.include?(pgroup_id) && max_status > Zena::Status[:red] )
        end
  
        # people who can write:
        # * super user
        # * owner
        # * members of +write_group+ if published and the current date is greater or equal to the publication date
        def can_write?(vis=visitor, ugps=visitor.group_ids)
          ( vis.is_su? ) || # super user
          ( vis[:id] == user_id ) ||
          ( ugps.include?(wgroup_id) && publish_from && Time.now >= publish_from )
        end
        
        # people who can make visible changes
        # * super user
        # * members of +publish_group+
        # * members of the reference's publish group if the item is private
        def can_visible?(vis=visitor, ugps=visitor.group_ids)
          ( vis.is_su? ) || # super user
          ( ugps.include?(pgroup_id) ) ||
          ( private? && ugps.include?(ref.pgroup_id))
        end
  
        # people who can manage:
        # * owner if +max_status+ <= red
        # * owner if private
        def can_manage?(vis=visitor)
          ( vis.is_su? ) || # super user
          ( publish_from == nil && vis[:id] == user_id && max_status <= Zena::Status[:red] ) ||
          ( private? && vis[:id] == user_id )
        end
        
        # can change position, name, rwp groups, etc
        def can_drive?
          can_manage? || can_visible?
        end
        
        def secure_before_validation
          unless @visitor
            errors.add('base', "record not secured")
            return false
          end
          self[:site_id] = @visitor.site[:id]
          if new_record?
            set_on_create
            secure_on_create
          else
            secure_on_update
          end
        end
        
        # Set owner and lang before validations on create (overwritten by multiversion)
        def set_on_create
          # set kpath 
          self[:kpath]    = self.class.kpath
          self[:user_id]  = visitor[:id]
          self[:ref_lang] = visitor.lang
        end
        
        # 1. validate the presence of a valid project (one in which the visitor has write access and project<>self !)
        # 2. validate the presence of a valid reference (project or parent) (in which the visitor has write access and ref<>self !)
        # 3. validate +publish_group+ value (same as parent or ref.can_visible? and valid)
        # 4. validate +rw groups+ :
        #     a. if can_visible? : valid groups
        #     b. else inherit or private
        # 5. validate the rest
        def secure_on_create
          # validate reference
          if ref == nil
            errors.add(ref_field, "invalid reference")
            return false
          end
          [:rgroup_id, :wgroup_id, :pgroup_id, :skin].each do |sym|
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
            self[:skin ] = ref.skin
          when -1
            # private
            if visitor.site[:allow_private]
              self[:rgroup_id] = 0
              self[:wgroup_id] = 0
              self[:pgroup_id] = 0
            else
              errors.add('inherit', "you cannot change this")
            end
          when 0
            if ref.can_visible?
              errors.add('rgroup_id', "unknown group") unless visitor.group_ids.include?(rgroup_id)
              errors.add('wgroup_id', "unknown group") unless visitor.group_ids.include?(wgroup_id)
              errors.add('pgroup_id', "unknown group") unless visitor.group_ids.include?(pgroup_id)
            elsif private?
              # ok
            else
              errors.add('inherit', "invalid value")
              errors.add('rgroup_id', "you cannot change this") unless rgroup_id == ref.rgroup_id
              errors.add('wgroup_id', "you cannot change this") unless wgroup_id == ref.wgroup_id
              errors.add('pgroup_id', "you cannot change this") unless pgroup_id == ref.pgroup_id
              errors.add('skin' , "you cannot change this") unless skin  == ref.skin
            end
          else
            errors.add('inherit', "bad inheritance mode")
          end

          # publish_from can only be set by the object itself by setting @publish_from
          self[:publish_from] = version.publish_from
          # same for proposed
          self[:max_status] = version.status
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
            if visitor.group_ids.include?(2) # admin group
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
                    ! secure_write!(ref_class) { ref_class.find(self[ref_field])} || 
                    ! secure_write!(ref_class) { ref_class.find(old[ref_field])}
                  errors.add(ref_field, "invalid reference") 
                  return false
                end
              else
                # node was visible, moves must be made with publish rights in both
                # source and destination
                if self[ref_field] == self[:id] ||
                    ! secure_drive!(ref_class) { ref_class.find(self[ref_field])} || 
                    ! secure_drive!(ref_class) { ref_class.find(old[ref_field])}
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
            while curr_ref != 0
              if ref_ids.include?(curr_ref) # detect loops
                ok = false
                break
              end
              ref_ids << curr_ref
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
            if inherit != old.inherit && !(old.can_visible? || ( old.can_manage? && (old.max_status_with_heirs < Zena::Status[:pub]) ))
              errors.add('inherit', 'you cannot change this')
              return false
            end
            
            # make sure rights are inherited. 
            [:rgroup_id, :wgroup_id, :pgroup_id, :skin].each do |sym|
              self[sym] = ref[sym]  
            end
          when -1
            # make private, only if owner
            unless (inherit == old.inherit)
              if old.can_drive? && (user_id == visitor[:id]) && visitor.site[:allow_private]
                [:rgroup_id, :wgroup_id, :pgroup_id].each do |sym|
                  self[sym] = 0
                end
              else
                errors.add('inherit', "you cannot change this")
              end
            end
          when 0
            if old.can_visible?
              if ref.can_visible?
                # can change groups
                if private?
                  # ok (all groups are 0)
                else
                  [:rgroup_id, :wgroup_id, :pgroup_id].each do |sym|
                    if self[sym] != 0 && self[sym] != old[:rgroup_id] && !visitor.group_ids.include?(self[sym])
                      errors.add(sym.to_s, "unknown group")
                    end
                  end
                end
              else
                # cannot change groups or inherit mode
                errors.add('inherit', "you cannot change this") unless inherit == old.inherit
                errors.add('rgroup_id', "you cannot change this") unless rgroup_id == old.rgroup_id
                errors.add('wgroup_id', "you cannot change this") unless wgroup_id == old.wgroup_id
                errors.add('pgroup_id', "you cannot change this") unless pgroup_id == old.pgroup_id
                # but you can change skins and name
              end
            else
              # must be the same as old
              errors.add('inherit', "you cannot change this") unless inherit == old.inherit
              errors.add('rgroup_id', "you cannot change this") unless rgroup_id == old.rgroup_id
              errors.add('wgroup_id', "you cannot change this") unless wgroup_id == old.wgroup_id
              errors.add('pgroup_id', "you cannot change this") unless pgroup_id == old.pgroup_id
              errors.add('skin', "you cannot change this") unless  skin  == old.skin
            end
          else
            errors.add('inherit', "bad inheritance mode")
          end
          @needs_inheritance_spread = (rgroup_id != old.rgroup_id || wgroup_id != old.wgroup_id || pgroup_id != old.pgroup_id || skin != old.skin)
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

        # Reference to validate access rights
        def ref
          return self if ref_field == :id && new_record? # new record and self as reference (creating root node)
          if !@ref || (@ref.id != self[ref_field])
            # no ref or ref changed
            @ref = secure!(ref_class) { ref_class.find(self[ref_field]) }
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
        # inheritance mode set to '1'. 17.2s
        # FIXME: make a single pass for spread_inheritance and update section_id and project_id ?
        # FIXME: should also remove cached pages...
        def spread_inheritance(i = self[:id])
          base_class.connection.execute "UPDATE nodes SET rgroup_id='#{rgroup_id}', wgroup_id='#{wgroup_id}', pgroup_id='#{pgroup_id}', skin='#{skin}' WHERE #{ref_field(false)}='#{i}' AND inherit='1'"
          ids = nil
          base_class.with_exclusive_scope do
            ids = base_class.fetch_ids("SELECT id FROM #{base_class.table_name} WHERE #{ref_field(true)} = '#{i.to_i}' AND inherit='1'")
          end
          
          ids.each { |i| spread_inheritance(i) }
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
              @old ||= secure_drive!(self.class) { self.class.find(self[:id]) }
            rescue ActiveRecord::RecordNotFound
              nil
            end
          end
        end
        
        # List of elements using the current element as a reference. Used to update
        # the rwp groups if they inherit from the reference. Can be overwritten by sub-classes.
        def heirs
          base_class.with_exclusive_scope do
            base_class.find(:all, :conditions=>["#{ref_field(true)} = ? AND inherit='1'" , self[:id] ] ) || []
          end
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
        def ref_field(for_heirs=false)
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
          #                Node --> N           
          #       Note --> NN          Page --> NP
          #                    Document   Form   Section
          #                       NPD      NPF      NPP
          # So now, to get all Pages, your sql becomes : WHERE kpath LIKE 'NP%'
          # to get all Documents : WHERE kpath LIKE 'NPD%'
          # all pages without Documents : WHERE kpath LIKE 'NP%' AND NOT LIKE 'NPD%'
          def kpath
            @@kpath[self] ||= superclass == ActiveRecord::Base ? ksel : (superclass.kpath + ksel)
          end
          
          # 'from' and 'joins' are removed: this method is used when receiving calls from zafu. Changing the source table removes
          # the secure scope.
          def clean_options(options)
            options.reject do |k,v|
              ! [ :conditions, :select, :include, :offset, :limit, :order, :lock ].include?(k)
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
        end
      end
    end
    
    # ============================================= SECURE  ===============
    module Secure
      # protect access to site_id : should not be changed by users
      def site_id=(i)
        raise Zena::AccessViolation, "#{self.class.to_s} '#{self.id}': tried to change 'site_id' to '#{i}'."
      end

      # Set current visitor
      def visitor=(visitor)
        @visitor = visitor
      end
      
      def inspect
        "#<#{self.class}:#{sprintf('%x',self.object_id)}\n" +
        "@attributes =\n{ " +
         ((@attributes || {}).sort.map do |k,v|
           sprintf("%15s => %s", k, v.inspect)
         end + [
            sprintf("%15s => %s", 'id', self[:id].inspect),
            sprintf("%15s => %s", '@new_record', new_record?.to_s),
            sprintf("%15s => %s", '@errors', (errors.map{|k,v| "#{k}:#{v}"}.join(', '))),
            sprintf("%15s => %s", '@visitor', (@visitor ? "User#{@visitor[:id]}" : 'nil'))
         ]).join("\n  ") + "} >"
      end
      
      # these methods are not actions that can be called from the web !!
      private
        # secure find with scope (for read/write or publish access).
        def secure_with_scope(klass, find_scope, opts={})
          if ((klass.send(:scoped_methods)[0] || {})[:create] || {})[:visitor]
            # we are already in secure scope: this scope is the new 'exclusive' scope.
            last_scope = klass.send(:scoped_methods).shift
          end

          scope = {:create => { :visitor => visitor }}
          if klass.ancestors.include?(User)
            scope[:find] ||= {}
            ptbl = Participation.table_name
            scope[:find][:joins] = "INNER JOIN #{ptbl} ON #{klass.table_name}.id = #{ptbl}.user_id AND #{ptbl}.site_id = #{visitor.site[:id]}"
            scope[:find][:readonly]   = false
            scope[:find][:select]     = "#{User.table_name}.*"
            scope[:find][:conditions] = find_scope
          elsif klass.column_names.include?('site_id')
            if find_scope
              find_scope = "(#{find_scope}) AND (#{klass.table_name}.site_id = #{visitor.site[:id]})"
            else
              find_scope = "#{klass.table_name}.site_id = #{visitor.site[:id]}"
            end
            scope[:find] = { :conditions => find_scope }
          elsif klass.ancestors.include?(Site)
            # TODO: write tests
            scope[:find] ||= {}
            ptbl = Participation.table_name
            scope[:find][:joins] = "INNER JOIN #{ptbl} ON #{klass.table_name}.id = #{ptbl}.site_id AND #{ptbl}.user_id = #{visitor[:id]} AND #{ptbl}.status = #{User::Status[:admin]}"
            scope[:find][:readonly]   = false
            scope[:find][:select]     = "#{Site.table_name}.*"
            scope[:find][:conditions] = find_scope
          end
          
          result = klass.with_scope( scope ) { yield }
          
          klass.send(:scoped_methods).unshift last_scope if last_scope
          
          return nil if result == []
          
          if result
            if klass.ancestors.include?(Node)
              if result.kind_of? Array
                result.each {|r| visitor.visit(r) }
              else
                visitor.visit(result)
              end
            end
            result
          else
            nil
          end
        end
      
        
        # Secure for read/create.
        # [read]
        # * super user
        # * owner
        # * members of +read_group+ if the node is published and the current date is greater or equal to the publication date
        # * members of +publish_group+ if +max_status+ >= prop
        # The options hash is used internally by zena when maintaining parent to children inheritance and should not be used for other purpose if you do not want to break secure access.
        def secure(klass, opts={}, &block)
          if opts[:secure] == false
            yield
          elsif klass.ancestors.include?(Zena::Acts::SecureNode::InstanceMethods) && !visitor.is_su? # not super user
            # ANY CHANGE HERE SHOULD BE REFLECTED IN has_relation secure_scope_string
            scope = "#{klass.table_name}.user_id = '#{visitor[:id]}' OR "+
                    "(rgroup_id IN (#{visitor.group_ids.join(',')}) AND #{klass.table_name}.publish_from <= now() ) OR " +
                    "(pgroup_id IN (#{visitor.group_ids.join(',')}) AND max_status > #{Zena::Status[:red]})"
            secure_with_scope(klass, scope, &block)
          else
            secure_with_scope(klass, nil, &block)
          end
        end
        
        def secure!(klass, opts={}, &block)
          unless res = secure(klass, opts={}, &block)
            raise ActiveRecord::RecordNotFound
          end
          res
        end
        

        # Secure scope for write access.
        # [write]
        # * super user
        # * owner
        # * members of +write_group+ if node is published and the current date is greater or equal to the publication date
        def secure_write!(obj, &block)
          res = if visitor.is_su? # super user
            secure_with_scope(obj, nil, &block)
          else
            scope = "user_id = '#{visitor[:id]}' OR "+
            "(wgroup_id IN (#{visitor.group_ids.join(',')}) AND publish_from <= now())"
            secure_with_scope(obj, scope, &block)
          end
          unless res
            raise ActiveRecord::RecordNotFound
          end
          res
        end
      
        # Secure scope for publish or management access. This scope is a little looser then 'secure' (read access) concerning redactions
        # and 'not published yet' nodes. This is not a bug, such an access is needed to delete old nodes for example.
        # [publish]
        # * super user
        # * members of +publish_group+
        # * owner if member of +publish_group+ or private
        # 
        # [manage]
        # * owner if +max_status+ <= red
        # * owner if private
        def secure_drive!(obj, &block)
          res = if visitor.is_su? # super user
            secure_with_scope(obj, nil, &block)
          else
            scope = "(user_id = '#{visitor[:id]}' AND ((rgroup_id = 0 AND wgroup_id = 0 AND pgroup_id = 0)) OR (max_status <= #{Zena::Status[:red]}))" +
                    " OR "+
                    "pgroup_id IN (#{visitor.group_ids.join(',')})"
            secure_with_scope(obj, scope, &block)
          end
          unless res
            raise ActiveRecord::RecordNotFound
          end
          res
        end
    end
  end
  # This exception handles all flagrant access violations or tentatives (like suppression of _su_ user)
  class AccessViolation < StandardError
  end
  
  # This exception occurs when a visitor is needed but none was provided.
  class RecordNotSecured < StandardError
  end
  
  # This exception occurs when corrupt data in encountered (infinit loops, etc)
  class InvalidRecord < StandardError
  end
end

### ============== GLOBAL METHODS ACCESSIBLE TO ALL OBJECTS ============== ######
# Return the current visitor. Raise an error if the visitor is not set.
# For controllers, this method must be redefined in Application
def visitor
  Thread.current.visitor
rescue NoMethodError
  raise Zena::RecordNotSecured.new("Visitor not set, record not secured.")
end

# Return the current site. Raise an error if the visitor is not set.
def current_site
  visitor.site
end

ActiveRecord::Base.send :include, Zena::Acts::Secure     # for other classes
ActiveRecord::Base.send :include, Zena::Acts::SecureNode # for Nodes
ActionController::Base.send :include, Zena::Acts::Secure