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

=== Who can do what (OBSOLTE: NEEDS UPDATE)
[read]
* super user
* owner
* members of +read_group+ if the node is published and the current date is greater or equal to the publication date
* members of +drive_group+ if +max_status+ >= prop

[write]
* super user
* owner
* members of +write_group+ if node is published and the current date is greater or equal to the publication date

[publish]
* super user
* members of +drive_group+ if +max_status+ >= prop
* owner if member of +drive_group+

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

      # this is called when the module is extended into the Node class
      def acts_as_secure_node
        belongs_to :rgroup, :class_name=>'Group', :foreign_key=>'rgroup_id'
        belongs_to :wgroup, :class_name=>'Group', :foreign_key=>'wgroup_id'
        belongs_to :pgroup, :class_name=>'Group', :foreign_key=>'pgroup_id'
        belongs_to :user
        before_validation  :secure_reference_before_validation
        # we move all before_validation on update and create here so that it is triggered before multiversion's before_validation
        before_validation  :secure_before_validation

        validate {|r| r.errors.add(:base, 'record not secured') unless r.instance_variable_get(:@visitor) }
        validate_on_update {|r| r.errors.add('site_id', 'cannot change') if r.site_id_changed? }

        validate_on_create :secure_on_create
        validate_on_update :secure_on_update

        before_save :secure_before_save
        after_save  :secure_after_save

        before_destroy :secure_on_destroy

        include Zena::Acts::SecureNode::InstanceMethods
        extend  Zena::Acts::SecureNode::ClassMethods
      end

      module InstanceMethods

        # Store visitor to produce scope when needed and to retrieve correct editions.
        def visitor=(visitor)
          @visitor = visitor
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
        # TODO: remove all eval_with_visitor stuff (should not be needed since visitor is a global)
        def eval_with_visitor(str)
          @eval_on_visitor ||= []
          @eval_on_visitor << str
          self
        end

        # Return true if the node can be viewed by all (public)
        def public?
          can_read?(visitor.site.anon,visitor.site.anon.group_ids) # visible by anonymous
        end

        # people who can read:
        # * super user
        # * members of +read_group+ if the node is published and the current date is greater or equal to the publication date
        # * members of +write_group+
        def can_read?(vis = visitor, ugps=visitor.group_ids)
          ( vis.is_su? ) || # super user
          ( ugps.include?(rgroup_id) && publish_from && Time.now >= publish_from ) ||
          ( ugps.include?(wgroup_id) )
        end

        # people who can write:
        # * super user
        # * members of +write_group+ if there status is at least 'user'.
        def can_write?(vis=visitor, ugps=visitor.group_ids)
          ( vis.is_su? ) ||             # super user
          ( ugps.include?(wgroup_id) && visitor.user?)  # write group
        end

        # The node has just been created so the creator can still delete it
        # or move it around.
        def draft?(vis=visitor)
          !publish_from && visitor.id == user_id &&
          visitor.user? && visitor.id == version.user_id &&
          versions.count == 1
        end

        # The node has just been created so the creator can still delete it
        # or move it around.
        def draft_was_true?(vis=visitor)
          !publish_from_was && visitor.id == user_id_was &&
          visitor.user? && visitor.id == version.user_id_was &&
          versions.count == 1
        end

        # Can alter node (move around, name, rwp groups, etc).
        # * super user
        # * members of +drive_group+ if member status is at least 'user'
        def can_drive?(vis=visitor, ugps=visitor.group_ids)
          ( vis.is_su? ) || # super user
          ( vis.user? && (ugps.include?(pgroup_id) || draft?) )
        end

        # 'can_drive?' before attribute change
        def can_drive_was_true?(vis=visitor, ugps=visitor.group_ids)
          ( vis.is_su? ) || # super user
          ( vis.user? && (ugps.include?(pgroup_id_was) || draft_was_true?) )
        end

        # 'can_drive?' without draft? exceptions
        def full_drive?(vis=visitor, ugps=visitor.group_ids)
          ( vis.is_su? ) || # super user
          ( vis.user? && ugps.include?(pgroup_id) )
        end

        # 'full_drive?' before attribute change
        def full_drive_was_true?(vis=visitor, ugps=visitor.group_ids)
          ( vis.is_su? ) || # super user
          ( vis.user? && ugps.include?(pgroup_id_was) )
        end

        def secure_before_validation
          if new_record?
            secure_before_validation_on_create
          else
            secure_before_validation_on_update
          end
        end

        def secure_before_validation_on_create
          # set defaults before validation
          self[:site_id]  = visitor.site.id
          self[:user_id]  = visitor.id
          self[:ref_lang] = visitor.lang

          [:rgroup_id, :wgroup_id, :pgroup_id, :skin].each do |sym|
            # not defined => inherit
            self[sym] ||= ref[sym]
            self[sym]   = 0 if self[sym].blank?
          end

          if inherit.nil?
            if rgroup_id == ref.rgroup_id && wgroup_id == ref.wgroup_id && pgroup_id == ref.pgroup_id
              self[:inherit] = 1
            else
              self[:inherit] = 0
            end
          end
          true
        end

        def secure_before_validation_on_update
          self[:kpath] = self.class.kpath
          true
        end

        # Make sure the reference object (the one from which this object inherits) exists before validating.
        def secure_reference_before_validation
          if ref == nil
            errors.add(ref_field, "invalid reference")
            return false
          end
          true
        end

        # 1. validate the presence of a valid project (one in which the visitor has write access and project<>self !)
        # 2. validate the presence of a valid reference (project or parent) (in which the visitor has write access and ref<>self !)
        # 3. validate +drive_group+ value (same as parent or ref.can_drive? and valid)
        # 4. validate +rw groups+ :
        #     a. if can_drive? : valid groups
        #     b. else inherit or private
        # 5. validate the rest
        def secure_on_create
          case inherit
          when 1
            # force inheritance
            self[:rgroup_id] = ref.rgroup_id
            self[:wgroup_id] = ref.wgroup_id
            self[:pgroup_id] = ref.pgroup_id
            self[:skin     ] = ref.skin
          when 0
            # custom access rights
            if ref.full_drive?
              errors.add('rgroup_id', "unknown group") unless visitor.group_ids.include?(rgroup_id)
              errors.add('wgroup_id', "unknown group") unless visitor.group_ids.include?(wgroup_id)
              errors.add('pgroup_id', "unknown group") unless visitor.group_ids.include?(pgroup_id)
            else
              errors.add('inherit', "custom access rights not allowed")
              errors.add('rgroup_id', "you cannot change this") unless rgroup_id == ref.rgroup_id
              errors.add('wgroup_id', "you cannot change this") unless wgroup_id == ref.wgroup_id
              errors.add('pgroup_id', "you cannot change this") unless pgroup_id == ref.pgroup_id
              errors.add('skin' , "you cannot change this") unless skin  == ref.skin
            end
          else
            errors.add(:inherit, "bad inheritance mode")
          end
        end

        # 1. if pgroup changed from old, make sure user could do this and new group is valid
        # 2. if owner changed from old, make sure only a user in 'admin' can do this
        # 3. error if user cannot publish nor manage
        # 4. parent/project changed ? verify 'publish access to new *and* old'
        # 5. validate +rw groups+ :
        #     a. can change to 'inherit' if can_drive? or can_drive? and max_status < pub and does not have children
        #     b. can change to 'private' if can_drive?
        #     c. can change to 'custom' if can_drive?
        # 6. validate the rest
        def secure_on_update
          return true unless changed?
          if !can_drive_was_true?
            errors.add(:base, 'you do not have the rights to do this')
            return false
          end

          if user_id_changed?
            if visitor.is_admin?
              # only admin can change owners
              # FIXME: AUTH: we are in 'secure' scope but we should fix this when changing authentication.
              unless User.find(:first, :conditions => ["id = ?",user_id])
                errors.add(:user_id, "unknown user")
              end
            else
              errors.add(:user_id, "only admins can change owners")
            end
          end

          return false unless ref_field_valid?

          # verify groups
          if inherit_changed? && !full_drive_was_true?
            errors.add(:inherit, 'you cannot change this')
          else
            case inherit
            when 1
              # inherit rights
              [:rgroup_id, :wgroup_id, :pgroup_id, :skin].each do |sym|
                if self.send("#{sym}_changed?") && self[sym] != ref[sym]
                  # manual change of value not allowed without changing inherit mode
                  errors.add(sym.to_s, 'cannot be changed without changing inherit mode')
                else
                  # in case parent changed, keep in sync
                  self[sym] = ref[sym]
                end
              end
            when 0
              # custom rights
              [:rgroup_id, :wgroup_id, :pgroup_id].each do |sym|
                if self.send("#{sym}_changed?") && !visitor.group_ids.include?(self[sym])
                  errors.add(sym.to_s, 'unknown group')
                end
              end
            else
              errors.add('inherit', 'bad inheritance mode')
            end
          end
        end

        # Prepare after save callbacks
        def secure_before_save
          @needs_inheritance_spread = !new_record? && (rgroup_id_changed? || wgroup_id_changed? || pgroup_id_changed? || skin_changed?)
          true
        end

        # Verify validity of the reference field.
        def ref_field_valid?
          return true unless ref_field_id_changed?
          # reference changed
          if published_in_heirs_was_true?
            # node or some children node was published, moves must be made with drive rights in both
            # source and destination
            if ref_field_id == self.id ||
               secure_drive(ref_class) {
                 ref_class.count(:conditions => ['id IN (?)', [ref_field_id, ref_field_id_was]]) != 2
               }
              errors.add(ref_field, "invalid reference")
              return false
            end
          else
            # node was not visible to others, we need write access to both source and destination
            if ref_field_id == self.id ||
                secure_write(ref_class) {
                  ref_class.count(:conditions => ['id IN (?)', [ref_field_id, ref_field_id_was]]) != 2
                }
              errors.add(ref_field, "invalid reference")
              return false
            end
          end
          in_circular_reference? ? false : true
        end

        # Make sure there is no circular reference
        # (any way to do this faster ?)
        def in_circular_reference?
          loop_ids = [self[:id]]
          curr_ref = ref_field_id
          in_loop  = false
          while curr_ref != 0
            if loop_ids.include?(curr_ref) # detect loops
              in_loop = true
              break
            end
            loop_ids << curr_ref
            curr_ref = Zena::Db.fetch_row("SELECT #{ref_field} FROM #{self.class.table_name} WHERE id=#{curr_ref}").to_i
          end

          errors.add(ref_field, 'circular reference') if in_loop
          in_loop
        end

        def secure_on_destroy
          if new_record? || can_drive_was_true?
            return true
          else
            errors.add('base', "you do not have the rights to do this")
            return false
          end
        end

        # Reference to validate access rights
        def ref
          # new record and self as reference (creating root node)
          return self if ref_field == :id && new_record?
          if !@ref || (@ref.id != ref_field_id)
            # no ref or ref changed
            reference = ref_class.find(:first, :conditions => ["id = ?", ref_field_id])
            @ref = secure(ref_class) { reference }
          end
          if @ref && (self.new_record? || (:id == ref_field) || (self[:id] != @ref[:id] ))
            # reference is accepted only if it is not the same as self or self is root (ref_field==:id set by Node)
            @ref.freeze
          else
            nil
          end
        end

        # Reference before attributes change
        def ref_was
          return self if ref_field == :id && new_record? # new record and self as reference (creating root node)
          if !@ref || (ref_field_id_changed?)
            # no ref or ref changed
            @ref_was = secure(ref_class) { ref_class.find(:first, :conditions => ["id = ?", ref_field_id_was]) }
          else
            @ref_was = @ref
          end
          if @ref_was && (self.new_record? || (:id == ref_field) || (self[:id] != @ref_was[:id] ))
            # reference is accepted only if it is not the same as self or self is root (ref_field==:id set by Node)
            @ref_was.freeze
          else
            nil
          end
        end

        protected

        def secure_after_save
          spread_inheritance if @needs_inheritance_spread
          true
        end

        # When the rwp groups are changed, spread this change to the 'children' with
        # inheritance mode set to '1'. 17.2s
        # FIXME: make a single pass for spread_inheritance and update section_id and project_id ?
        # FIXME: should also remove cached pages...
        def spread_inheritance(i = self[:id])
          base_class.connection.execute "UPDATE nodes SET rgroup_id='#{rgroup_id}', wgroup_id='#{wgroup_id}', pgroup_id='#{pgroup_id}', skin='#{skin}' WHERE #{ref_field(false)}='#{i}' AND inherit='1'"
          ids = nil
          # FIXME: remove 'with_exclusive_scope' once scopes are clarified and removed from 'secure'
          base_class.send(:with_exclusive_scope) do
            ids = Zena::Db.fetch_ids("SELECT id FROM #{base_class.table_name} WHERE #{ref_field(true)} = '#{i.to_i}' AND inherit='1'")
          end

          ids.each { |i| spread_inheritance(i) }
        end

        # Return true if a heir is published.
        def published_in_heirs?
          pub = publish_from
          return true if pub
          heirs.each do |h|
            break if pub = h.published_in_heirs?
          end
          return pub
        end

        # Return true if a heir is published.
        def published_in_heirs_was_true?
          pub = publish_from_was
          return true if pub
          heirs.each do |h|
            break if pub = h.published_in_heirs?
          end
          return pub
        end

        private

        # List of elements using the current element as a reference. Used to update
        # the rwp groups if they inherit from the reference. Can be overwritten by sub-classes.
        def heirs
          # FIXME: remove 'with_exclusive_scope' once scopes are clarified and removed from 'secure'
          base_class.send(:with_exclusive_scope) do
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

        def ref_field_id
          self[ref_field]
        end

        def ref_field_id_was
          self.send(:"#{ref_field}_was")
        end

        def ref_field_id_changed?
          self.send(:"#{ref_field}_changed?")
        end

      end # InstanceMethods

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

      end # ClassMethods

    end #SecureNode

    # ============================================= SECURE  ===============
    module Secure

      # protect access to site_id : should not be changed by users
      # def site_id=(i)
      #   raise Zena::AccessViolation, "#{self.class.to_s} '#{self.id}': tried to change 'site_id' to '#{i}'."
      # end

      # Set current visitor
      def visitor=(visitor)
        @visitor = visitor
      end

      # Check if module Secure is included
      def secure?
        true
      end

      # these methods are not actions that can be called from the web !!
      protected
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
          elsif klass.ancestors.include?(Version)
            scope[:find] ||= {}
            ntbl = Node.table_name
            scope[:find][:joins] = "INNER JOIN #{ntbl} ON #{klass.table_name}.node_id = #{ntbl}.id"
            scope[:find][:readonly]   = false
            scope[:find][:conditions] = secure_scope(ntbl)
          elsif klass.column_names.include?('site_id')
            if find_scope && !opts[:site_id_clause_set]
              find_scope = "(#{find_scope}) AND (#{klass.table_name}.site_id = #{visitor.site[:id]})"
            elsif !opts[:site_id_clause_set]
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

          # FIXME: 'with_scope' is protected now. Can we live with something cleaner like this ?
          # class AR::Base
          #   def self.secure_find(...)
          #      ...
          #   end
          # end
          #
          # or better:
          #  :conditions => '#{secure_scope}' (dynamically evaluated: single quotes)
          result = klass.send(:with_scope, scope) { yield }

          klass.send(:scoped_methods).unshift last_scope if last_scope

          secure_result(klass,result)
        end

        def secure_result(klass,result)
          if result && result != []
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
        # * members of +drive_group+ if +max_status+ >= prop
        # The options hash is used internally by zena when maintaining parent to children inheritance and should not be used for other purpose if you do not want to break secure access.
        def secure(klass, opts={}, &block)
          if opts[:secure] == false
            yield
          elsif klass.ancestors.include?(Zena::Acts::SecureNode::InstanceMethods) && !visitor.is_su? # not super user
            secure_with_scope(klass, secure_scope(klass.table_name), :site_id_clause_set => true, &block)
          else
            secure_with_scope(klass, nil, &block)
          end
        rescue ActiveRecord::RecordNotFound
          # Rails generated exceptions
          # TODO: monitor how often this happens and replace the finders concerned
          nil
        end

        def secure!(klass, opts={}, &block)
          unless res = secure(klass, opts={}, &block)
            raise ActiveRecord::RecordNotFound
          end
          res
        end

        # Secure scope for read access
        def secure_scope(table_name)
          if visitor.is_su?
            "#{table_name}.site_id = #{visitor.site.id}"
          else
            # site_id AND...
            "#{table_name}.site_id = #{visitor.site.id} AND ("+
            # READER if published
            "(#{table_name}.rgroup_id IN (#{visitor.group_ids.join(',')}) AND #{table_name}.publish_from <= #{Zena::Db::NOW} ) OR " +
            # OR writer
            "#{table_name}.wgroup_id IN (#{visitor.group_ids.join(',')}))"
          end
        end

        # Secure scope for write access.
        # [write]
        # * super user
        # * owner
        # * members of +write_group+ if node is published and the current date is greater or equal to the publication date
        def secure_write(obj, &block)
          if visitor.is_su? # super user
            secure_with_scope(obj, nil, &block)
          else
            scope = "wgroup_id IN (#{visitor.group_ids.join(',')})"
            secure_with_scope(obj, scope, &block)
          end
        rescue ActiveRecord::RecordNotFound
          # Rails generated exceptions
          # TODO: monitor how often this happens and replace the finders concerned
          nil
        end

        # Find a node with write access. Raises an exception on failure.
        def secure_write!(obj, &block)
          unless res = secure_write(obj, &block)
            raise ActiveRecord::RecordNotFound
          end
          res
        end

        # Secure scope for publish or management access. This scope is a little looser then 'secure' (read access) concerning redactions
        # and 'not published yet' nodes. This is not a bug, such an access is needed to delete old nodes for example.
        # [publish]
        # * super user
        # * members of +drive_group+
        # * owner if member of +drive_group+ or private
        #
        # [manage]
        # * owner if +max_status+ <= red
        # * owner if private
        def secure_drive(obj, &block)
          if visitor.is_su? # super user
            secure_with_scope(obj, nil, &block)
          else
            scope = "pgroup_id IN (#{visitor.group_ids.join(',')})"
            secure_with_scope(obj, scope, &block)
          end
        rescue ActiveRecord::RecordNotFound
          # Rails generated exceptions
          # TODO: monitor how often this happens and replace the finders concerned
          nil
        end

        # Find nodes with 'drive' authorization. Raises an exception on failure.
        def secure_drive!(obj, &block)
          if res = secure_drive(obj, &block)
            res
          else
            raise ActiveRecord::RecordNotFound
          end
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

# FIXME: these modules should be included in specific model in order to be
# more readable and maintable.
ActiveRecord::Base.send :include, Zena::Acts::Secure     # for other classes
#ActiveRecord::Base.send :include, Zena::Acts::SecureNode # for Nodes
ActionController::Base.send :include, Zena::Acts::Secure
