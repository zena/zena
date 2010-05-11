module Zena
  module Acts
    module SecureNode

      # this is called when the module is extended into the Node class
      def acts_as_secure_node
        belongs_to :rgroup, :class_name=>'Group', :foreign_key=>'rgroup_id'
        belongs_to :wgroup, :class_name=>'Group', :foreign_key=>'wgroup_id'
        belongs_to :dgroup, :class_name=>'Group', :foreign_key=>'dgroup_id'
        belongs_to :user
        before_validation  :secure_reference_before_validation
        # we move all before_validation on update and create here so that it is triggered before multiversion's before_validation
        before_validation  :secure_before_validation

        validate :record_must_be_secured
        #validate {|r| r.errors.add(:base, 'record not secured') unless r.instance_variable_get(:@visitor)}
        validate_on_update {|r| r.errors.add('site_id', 'cannot change') if r.site_id_changed? }

        validate_on_create :secure_on_create
        validate_on_update :secure_on_update

        before_save :secure_before_save
        after_save  :secure_after_save

        before_destroy :secure_on_destroy

        include Zena::Acts::SecureNode::InstanceMethods

        class << self

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
          attr_accessor :kpath

          def kpath
            @kpath ||= make_kpath
          end

          private
            def make_kpath
              superclass.respond_to?(:kpath) ? (superclass.kpath + ksel) : ksel
            end
        end

        extend  Zena::Acts::SecureNode::ClassMethods
      end

      module InstanceMethods

        def record_must_be_secured
          errors.add(:base, 'record not secured') unless secured?
        end

        # Store visitor to produce scope when needed and to retrieve correct editions.
        def visitor=(visitor)
          @visitor = visitor
          self
        end

        # Return true if the node can be viewed by all (public)
        def public?
          can_read?(visitor.site.anon,visitor.site.anon.group_ids) # visible by anonymous
        end

        # Return true if the node is properly secured (was loaded with secure)
        def secured?
          @visitor && @visitor == Thread.current[:visitor]
        end

        # Return true if the node is not a reference for any other nodes
        def empty?
          return true if new_record?
          0 == self.class.count_by_sql("SELECT COUNT(*) FROM #{self.class.table_name} WHERE #{ref_field} = #{self[:id]}")
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

        # Returns true if the current visitor can see redactions (unpublished versions)
        # of the node.
        def can_see_redactions?(ugps = visitor.group_ids)
          visitor.group_ids.include?(wgroup_id)
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
          ( vis.user? && (ugps.include?(dgroup_id) || draft?) )
        end

        # 'can_drive?' before attribute change
        def can_drive_was_true?(vis=visitor, ugps=visitor.group_ids)
          ( vis.is_su? ) || # super user
          ( vis.user? && (ugps.include?(dgroup_id_was) || draft_was_true?) )
        end

        # 'can_drive?' without draft? exceptions
        def full_drive?(vis=visitor, ugps=visitor.group_ids)
          ( vis.is_su? ) || # super user
          ( vis.user? && ugps.include?(dgroup_id) )
        end

        # 'full_drive?' before attribute change
        def full_drive_was_true?(vis=visitor, ugps=visitor.group_ids)
          ( vis.is_su? ) || # super user
          ( vis.user? && ugps.include?(dgroup_id_was) )
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

          [:rgroup_id, :wgroup_id, :dgroup_id, :skin].each do |sym|
            # not defined => inherit
            self[sym] ||= ref[sym]
          end

          if inherit.nil?
            if rgroup_id == ref.rgroup_id && wgroup_id == ref.wgroup_id && dgroup_id == ref.dgroup_id
              self[:inherit] = 1
            else
              self[:inherit] = 0
            end
          end
          true
        end

        def secure_before_validation_on_update
          self[:kpath] = self.vclass.kpath if vclass_id_changed? or type_changed?
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
            self[:dgroup_id] = ref.dgroup_id
            self[:skin     ] = ref.skin
          when 0
            # custom access rights
            if ref.full_drive?
              errors.add('rgroup_id', "unknown group") unless visitor.group_ids.include?(rgroup_id)
              errors.add('wgroup_id', "unknown group") unless visitor.group_ids.include?(wgroup_id)
              errors.add('dgroup_id', "unknown group") unless visitor.group_ids.include?(dgroup_id)
            else
              errors.add('inherit', "custom access rights not allowed")
              errors.add('rgroup_id', "you cannot change this") unless rgroup_id == ref.rgroup_id
              errors.add('wgroup_id', "you cannot change this") unless wgroup_id == ref.wgroup_id
              errors.add('dgroup_id', "you cannot change this") unless dgroup_id == ref.dgroup_id
              errors.add('skin' , "you cannot change this") unless skin  == ref.skin
            end
          else
            errors.add(:inherit, "bad inheritance mode")
          end

        end

        # 1. if dgroup changed from old, make sure user could do this and new group is valid
        # 2. if owner changed from old, make sure only a user in 'admin' can do this
        # 3. error if user cannot publish nor manage
        # 4. parent/project changed ? verify 'publish access to new *and* old'
        # 5. validate +rw groups+ :
        #     a. can change to 'inherit' if can_drive? or can_drive? and max_status < pub and does not have children
        #     b. can change to 'private' if can_drive?
        #     c. can change to 'custom' if can_drive?
        # 6. validate the rest
        def secure_on_update
          if !changed_without_properties?
            # Node hasn't been changed (only version edits)
            return true
          end

          if !can_drive_was_true?
            errors.add(:base, 'You do not have the rights to do this.') unless errors[:base]
            return false
          end

          if user_id_changed?
            if visitor.is_admin?
              # only admin can change owners
              unless secure(User) { User.find_by_id(user_id) }
                errors.add(:user_id, 'unknown user')
              end
            else
              errors.add(:user_id, 'Only admins can change owners')
            end
          end

          return false unless ref_field_valid?

          # verify groups
          if inherit_changed? && !full_drive_was_true?
            errors.add(:inherit, 'cannot be changed')
          else
            case inherit
            when 1
              # inherit rights
              [:rgroup_id, :wgroup_id, :dgroup_id, :skin_id].each do |sym|
                if self.send("#{sym}_changed?") && self[sym] != ref[sym]
                  # manual change of value not allowed without changing inherit mode
                  if !full_drive_was_true?
                    errors.add(sym.to_s, 'cannot be changed')
                  else
                    errors.add(sym.to_s, 'cannot be changed without changing inherit mode')
                  end
                else
                  # in case parent changed, keep in sync
                  self[sym] = ref[sym]
                end
              end
            when 0
              # custom rights
              [:rgroup_id, :wgroup_id, :dgroup_id].each do |sym|
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
          @needs_inheritance_spread = !new_record? && (rgroup_id_changed? || wgroup_id_changed? || dgroup_id_changed? || skin_id_changed?)
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
            unless empty?
              errors.add(:base, 'cannot be removed (contains subpages or data)')
              false
            else
              true
            end
          else
            errors.add(:base, 'You do not have the rights to destroy.')
            false
          end
        end

        # Reference to validate access rights
        def ref
          # new record and self as reference (creating root node)
          return self if ref_field == :id && new_record?
          if !@ref || (@ref.id != ref_field_id)
            # no ref or ref changed
            @ref = secure(ref_class) { ref_class.find_by_id(ref_field_id) }
          end
          if @ref && (self.new_record? || (:id == ref_field) || (self[:id] != @ref[:id] ))
            # reference is accepted only if it is not the same as self or self is root (ref_field==:id set by Node)
            @ref.freeze
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
          base_class.connection.execute "UPDATE nodes SET rgroup_id='#{rgroup_id}', wgroup_id='#{wgroup_id}', dgroup_id='#{dgroup_id}', skin_id='#{skin_id}' WHERE #{ref_field(false)}='#{i}' AND inherit='1'"
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

        # Replace Rails subclasses normal behavior
        def type_condition
          " #{table_name}.kpath LIKE '#{kpath}%' "
        end
      end # ClassMethods

    end #SecureNode
  end # Acts
end # Zena