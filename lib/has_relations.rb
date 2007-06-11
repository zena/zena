module Zena
  module Relations
    def self.plural_method?(method)
      m = method.split('_').first
      m.pluralize == m || method.ends_with?('_for')
    end
  
    module HasRelations
      # this is called when the module is included into the 'base' module
      def self.included(base)
        # add all methods from the module "AddActsAsMethod" to the 'base' module
        base.extend Zena::Relations::ClassMethods
      end
    end
    
    module ClassMethods
      def has_relations(opts={})
        opts[:class] ||= self
        validate      :valid_links
        after_save    :update_links
        after_destroy :destroy_links
        
        class_eval <<-END
        include Zena::Relations::InstanceMethods
          def relation_base_class
            #{opts[:class]}
          end
        END
      end
    end

    module InstanceMethods

      def fetch_relation(role, opts={})
        return nil unless relation = relation_proxy(:role => role, :from => opts[:from])
        relation.records(opts)
      end
      
      def set_relation(role, value)
        @relations_to_update ||= []
        @relations_to_update << [:set, [role, value]]
      end
      
      def remove_link(link_id)
        @relations_to_update ||= []
        @relations_to_update << [:remove, link_id]
      end
      
      def add_link(role, value)
        @relations_to_update ||= []
        @relations_to_update << [:add, [role, value]]
      end

      def valid_links
        return true unless @relations_to_update
        @valid_relations_to_update = []
        @relations_to_update.map do |action, params|
          case action
          when :set
            role, value = params
            if relation = relation_proxy(:role => role)
              relation.new_value = value
              if relation.links_valid?
                @valid_relations_to_update << relation
              else
                errors.add(role, relation.link_errors.join(', '))
              end
            else
              errors.add(role, 'undefined relation')
            end
          when :add
            role, value = params
            if relation = relation_proxy(:role => role)
              relation << value
              if relation.links_valid?
                @valid_relations_to_update << relation
              else
                errors.add(role, relation.link_errors.join(', '))
              end
            else
              errors.add(role, 'undefined relation')
            end
          when :remove
            link_id = params
            link = Link.find(:first, :conditions => ['(source_id = ? OR target_id = ?) AND id = ?', self[:id], self[:id], link_id])
            if relation = relation_proxy(:link => link)
              if link['source_id'] == self[:id]
                relation.delete(link['target_id'])
              else
                relation.delete(link['source_id'])
              end
              if relation.links_valid?
                @valid_relations_to_update << relation
              else
                errors.add(role, relation.link_errors.join(', '))
              end
            else
              errors.add('base', 'unknown link')
            end
          end
        end
        
      end
      
      def update_links
        return if @valid_relations_to_update.blank?
        @valid_relations_to_update.each do |relation|
          relation.update_links!
        end
        remove_instance_variable(:@valid_relations_to_update)
        remove_instance_variable(:@relations_to_update)
      end
      
      # 'NPD' ==> 'N', 'NP', 'NPD'
      def split_kpath
        @split_kpath ||= begin
          klasses   = []
          kpath     = self.class.kpath
          kpath.split(//).each_index { |i| klasses << kpath[0..i] } 
          klasses
        end
      end


      def relation_proxy(opts={})
        if role = opts[:role]
          role_name = role.singularize
          if opts[:from]
            # ignore source class
            conditions = ["site_id = ? AND (target_role = ? OR source_role = ?)", current_site[:id], role_name, role_name]
          else
            conditions = ["site_id = ? AND ((target_role = ? AND source_kpath IN (?)) OR (source_role = ? AND target_kpath IN (?)))", current_site[:id], role_name, split_kpath, role_name, split_kpath]
          end
          relation = Relation.find(:first, :conditions => conditions)
          if relation
            if relation.target_role == role_name
              relation.source = self
            else
              relation.target = self
            end
          end
        elsif link = opts[:link]
          return nil unless link
          if link.source_id == self[:id]
            conditions = ["site_id = ? AND id = ? AND source_kpath IN (?)", current_site[:id], link.relation_id, split_kpath]
          else
            conditions = ["site_id = ? AND id = ? AND target_kpath IN (?)", current_site[:id], link.relation_id, split_kpath]
          end
          relation = Relation.find(:first, :conditions => conditions)
          if relation
            if link.source_id == self[:id]
              relation.source = self
            else
              relation.target = self
            end
          end
        end
        relation
      end
      
      private
        
        # shortcut accessors like tags_id = ...
        def method_missing(meth, *args)
          if meth.to_s =~ /^([\w_]+)(_(id|zip)s?)(=?)$/
            role = $1
            type = $3
            mode = $4
            if relation = relation_proxy(:role => role)
              if mode == '='
                super if type == 'zip'
                set_relation(role,args[0])
              else
                # get ids / zips
                relation.records.map { |obj| obj[type] }
              end
            else
              super # unknown relation
            end
          else
            super # no _zip / _id
          end
        end
    end
  end
end

ActiveRecord::Base.send :include, Zena::Relations::HasRelations