module Zena
  module Use
    module ScopeIndex
      AVAILABLE_MODELS = []

      def self.models_for_form
        [''] + AVAILABLE_MODELS.map(&:to_s)
      end

      module VirtualClassMethods
        def self.included(base)
          base.class_eval do
            validate :validate_idx_class, :validate_idx_scope
            attr_accessible :idx_class, :idx_scope, :idx_reverse_scope
            property do |p|
              p.string 'idx_class'
              p.string 'idx_scope'
              p.string 'idx_reverse_scope'
            end
            self.export_attributes += %w{idx_class idx_scope idx_reverse_scope}
          end
        end

        protected
          def validate_idx_class
            self.idx_class = nil if self.idx_class.blank?

            if model_name = self.idx_class
              if model_name =~ /\A[A-Z][a-zA-Z]+\Z/
                if klass = Zena.const_get(model_name) rescue NilClass
                  if klass < Zena::Use::ScopeIndex::IndexMethods
                    # ok
                  else
                    errors.add('idx_class', 'invalid class (should include ScopeIndex::IndexMethods)')
                  end
                else
                  errors.add('idx_class', 'invalid class')
                end
              else
                errors.add('idx_class', 'invalid class name')
              end
            end
          end

          def validate_idx_scope
            self.idx_scope = nil if self.idx_scope.blank?
            if scopes = self.idx_scope
              # Try to compile query in instance of class self
              begin
                scopes = new_instance.safe_eval scopes
                if scopes.kind_of?(Hash)
                  scopes.each do |keys, query|
                    unless keys.kind_of?(String) &&
                      (
                        query.kind_of?(String) ||
                       (query.kind_of?(Array) && query.inject(true){|s,k| s && k.kind_of?(String)}))
                      errors.add('idx_scope', "Invalid entry: keys should be a String and query should be a String or an Array of strings (#{keys.inspect} => #{query.inspect})")
                      next
                    end
                    begin
                      Array(query).each do |q|
                        real_class.build_query(:all, q,
                          :node_name       => 'self',
                          :main_class      => self,
                          :rubyless_helper => self
                        )
                      end
                    rescue ::QueryBuilder::Error => err
                      errors.add('idx_scope', "Invalid query: #{err.message}")
                    end
                  end
                else
                  errors.add('idx_scope', "Invalid type: should be a hash.")
                end
              rescue ::RubyLess::Error => err
                errors.add('idx_scope', "Invalid rubyless: #{err.message}")
              end
            end
          end
      end # VirtualClassMethods

      module IndexMethods
        def self.included(base)
          AVAILABLE_MODELS << base

          class << base
            attr_accessor :groups
          end

          base.class_eval do
            include RubyLess
            before_validation     :set_site_id
            validates_presence_of :node_id
          end

          groups = base.groups = {}
          base.column_names.each do |name|
            next if %{created_at updated_at id node_id site_id}.include?(name)
            if name =~ %r{\A([^_]+)_(.+)\Z}
              (groups[$1] ||= []) << $2
              unless $2 == 'id'
                base.safe_attribute name
              end
            end
          end
        end

        # The given node has been updated in the owner's project. Update index
        # entries with this node's content if necessary.
        def update_with(node, keys, force_create = false)
          attrs = {}
          prop_column_names = node.schema.column_names
          groups = self.class.groups
          keys.each do |group_key|
            next unless list = groups[group_key]
            next unless should_update_group?(group_key, node)
            list.each do |key|
              if prop_column_names.include?(key)
                attrs["#{group_key}_#{key}"] = node.prop[key]
              elsif node.respond_to?(key)
                attrs["#{group_key}_#{key}"] = node.send(key)
              end
            end
          end

          if !attrs.empty? || force_create
            self.attributes = attrs
            save
          end
        end

        def update_after_destroy(deleted_node, keys)
          groups = self.class.groups
          attrs  = {}
          keys.each do |group_key|
            next unless list = groups[group_key]
            next unless should_clear_group?(group_key, deleted_node)
            list.each do |key|
              attrs["#{group_key}_#{key}"] = nil
            end
          end

          if !attrs.empty?
            self.attributes = attrs
            save
          end
        end

        # Return true if the indices from the given group should be altered by the node.
        def should_update_group?(group_key, node)
          node.id >= self["#{group_key}_id"].to_i
        end

        # Return true if the indices from the given group should be cleared when
        # the given node is deleted.
        def should_clear_group?(group_key, deleted_node)
          deleted_node.id == self["#{group_key}_id"].to_i
        end

        def set_site_id
          self[:site_id] = current_site.id
        end
      end # ModelMethods

      module ModelMethods
        def self.included(base)
          base.after_save    :update_scope_indices
          base.after_destroy :update_scope_indices_on_destroy
          base.safe_context :scope_index => scope_index_proc
          base.alias_method_chain :rebuild_index!, :scope_index
        end

        def self.scope_index_proc
          Proc.new do |helper, receiver, signature|
            if receiver.respond_to?('idx_class') && receiver.idx_class && klass = Zena.resolve_const(receiver.idx_class) rescue nil
              {:method => 'scope_index', :nil => true, :class => klass}
            else
              raise RubyLess::NoMethodError.new(receiver, receiver, signature)
            end
          end
        end

        # Rebuild 'remote' indexes based on changes in this node.
        def rebuild_index_with_scope_index!
          rebuild_index_without_scope_index!
          update_scope_indices
        end

        # Access the index model inside the Project or Section.
        def scope_index
          @scope_index ||= begin
            vclass = virtual_class
            if vclass && klass = vclass.idx_class
              if klass = Zena.resolve_const(klass) rescue nil
                klass.find(:first, :conditions => {:node_id => self.id, :site_id => current_site.id}) || klass.new(:node_id => self.id)
              else
                nil
              end
            else
              nil
            end
          end
        end

        # Trigger 'rebuild_index!' in all elements that could affect this model's
        # scope index.
        def rebuild_scope_index!
          if vclass && query = vclass.idx_reverse_scope
            if nodes = find(:all, query)
              nodes.each do |node|
                node.rebuild_index!
              end
            end
          else
            nil
          end

        end

        protected
          # Update scope indices (project/section).
          def update_scope_indices
            return unless version.status == Zena::Status[:pub]
            update_scope_indices_on_prop_change
            update_scope_indices_on_link_change
           rescue ::QueryBuilder::Error
             # log and ignore: we cannot recover here ?
             # FIXME: raise when we have transactional save.
          end

          def update_scope_indices_on_destroy
            update_scope_indices_on_prop_change(true)
            # How can we handle this ?
            # update_scope_indices_on_link_change
          end

          def update_scope_indices_on_prop_change(deleted=false)
            if virtual_class && scopes = virtual_class.idx_scope
              scopes = safe_eval(scopes)
              return unless scopes.kind_of?(Hash)
              mapped_scopes = []
              scopes.each do |keys, queries|
                # Change key ('project,contract') to an array
                keys = keys.split(',').map(&:strip) if keys.kind_of?(String)
                Array(queries).each do |query|
                  mapped_scopes << [keys, query]
                end
              end

              mapped_scopes.each do |keys, query|
                next unless query.kind_of?(String) && keys.kind_of?(Array) && keys.inject(true) {|s,k| s && k.kind_of?(String) }
                if query.strip == 'self'
                  next if deleted
                  models_to_update = [self]
                else
                  models_to_update = find(:all, query, :skip_rubyless => true) || []
                end

                models_to_update.each do |m|
                  next if m.destroyed? # on destroy, self can be in this list
                  if idx_model = m.scope_index
                    if deleted
                      # Clear obsolete content
                      idx_model.update_after_destroy(self, keys)
                      # Rebuild index
                      m.rebuild_scope_index!
                    else
                      # force creation of index record
                      idx_model.update_with(self, keys, true)
                    end
                  end
                end
              end
            end
          end

          def update_scope_indices_on_link_change
            (@relation_proxies || {}).values.compact.each do |rel|
              if add_links = rel.add_links
                add_links.each do |hash|
                  if node = hash[:node]
                    node.update_scope_indices
                  end
                end
              end
            end
          end
      end # ModelMethods
    end # ScopeIndex
  end # Acts
end # Zena