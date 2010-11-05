module Zena
  module Use
    module ScopeIndex
      AVAILABLE_MODELS = []

      def self.models_for_form
        AVAILABLE_MODELS.map(:to_s)
      end

      module VirtualClassMethods
        def self.included(base)
          AVAILABLE_MODELS << base
          base.validate :valid_scope_index
          base.attr_accessible :scope_index
        end

        protected
          def valid_scope_index
            if model_name = self[:scope_index]
              if model_name =~ /\A[A-Z][a-zA-Z]+\Z/
                if klass = Zena.const_get(model_name) rescue NilClass
                  if klass < Zena::Use::ScopeIndex::IndexMethods
                    # ok
                  else
                    errors.add('scope_index', 'invalid model (should include ScopeIndex::IndexMethods)')
                  end
                else
                  errors.add('scope_index', 'invalid model')
                end
              else
                errors.add('scope_index', 'invalid model name')
              end
            end
          end
      end # VirtualClassMethods

      module IndexClassMethods
        # Return the column groups for which the node with the given kpath should
        # be used alter index values.
        def match_groups(kpath)
          groups.keys.select {|key| kpath =~ %r{\A#{key}}}
        end
      end # ClassMethods

      module IndexMethods
        def self.included(base)
          class << base
            attr_accessor :groups
          end

          groups = base.groups = {}

          base.column_names.each do |name|
            next if %{created_at updated_at id node_id}.include?(name)
            if name =~ %r{\A([A-Z]+)_(.+)\Z}
              (groups[$1] ||= []) << $2
            end
          end

          base.class_eval do
            extend IndexClassMethods
            before_validation     :set_site_id
            validates_presence_of :node_id
          end
        end

        # The given node has been updated in the owner's project. Update index
        # entries with this node's content if necessary.
        def update_with(node, force_create = false)
          attrs = {}
          self.class.match_groups(node.kpath).each do |group_key|
            next unless should_update_group?(group_key, node)
            self.class.groups[group_key].each do |key|
              attrs["#{group_key}_#{key}"] = node.send(key)
            end
          end

          if !attrs.empty? || force_create
            self.attributes = attrs
            save
          end
        end

        # Return true if the indices from the given group should be altered by the node.
        def should_update_group?(group_key, node)
          node.id >= self["#{group_key}_id"].to_i
        end

        def set_site_id
          self[:site_id] = current_site.id
        end
      end # ModelMethods

      module ModelMethods
        def self.included(base)
          if Bricks::CONFIG['scope_index']
            base.after_save :update_model_indices
            base.safe_context :scope_index => scope_index_proc
          end
        end

        def self.scope_index_proc
          Proc.new do |helper, signature|
            if helper < Project || helper < Section
              vclass = helper.klass
              if vclass && vclass.scope_index && klass = Zena.resolve_const(vclass.scope_index)
                {:method => 'scope_index', :nil => true, :class => klass}
              else
                raise RubyLess::NoMethodError.new(helper, helper, signature)
              end
            else
              raise RubyLess::Error.new("#{helper} is not a Project or Section: cannot have a scope_index.")
            end
          end
        end

        # Access the index model inside the Project or Section.
        def scope_index
          @scope_index ||= begin
            vclass = virtual_class
            if vclass && klass = vclass.scope_index
              if klass = Zena.const_get(klass.gsub(/[^a-zA-Z]/, ''))
                klass.find(:first, :conditions => {:node_id => self.id, :site_id => current_site.id})
              end
            else
              nil
            end
          end
        end

        protected
          # Update scope indices (project/section).
          def update_model_indices
            if kind_of?(Project) || kind_of?(Section)
              update_model_indices_for(self.id, force_create = true)
            else
              update_model_indices_for(self.project_id)
              update_model_indices_for(self.section_id)
            end
          end

          # Update Project/Section index inside the sub-nodes.
          def update_model_indices_for(model_id, force_create = false)
            if vclass = VirtualClass.find(:first,
                :joins => ["INNER JOIN nodes ON nodes.vclass_id = roles.id AND nodes.id = #{model_id}"]
              )
              if model_name = vclass.scope_index
                klass = Zena.const_get(model_name.gsub(/[^a-zA-Z]/, ''))
                unless scope_index = klass.find(:first, :conditions => ['node_id = ?', model_id])
                  scope_index = klass.new(:node_id => model_id)
                end
                @scope_index = scope_index
                scope_index.update_with(self, force_create)
              end
            end
          end
      end # ModelMethods
    end # ScopeIndex
  end # Acts
end # Zena