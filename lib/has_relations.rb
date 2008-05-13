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
      
      def split_kpath
        @split_kpath ||= begin
          klasses   = []
          kpath.split(//).each_index { |i| klasses << kpath[0..i] } 
          klasses
        end
      end
      
      def find_relation(opts)
        role_name = (opts[:role] || '').singularize
        if opts[:id]
          if opts[:source]
            conditions = ["site_id = ? AND id = ? AND source_kpath IN (?)", current_site[:id], opts[:id], split_kpath]
          else
            conditions = ["site_id = ? AND id = ? AND target_kpath IN (?)", current_site[:id], opts[:id], split_kpath]
          end
        else
          if opts[:from] || opts[:ignore_source]
            conditions = ["site_id = ? AND (target_role = ? OR source_role = ?)", current_site[:id], role_name, role_name]
          else
            conditions = ["site_id = ? AND ((target_role = ? AND source_kpath IN (?)) OR (source_role = ? AND target_kpath IN (?)))", current_site[:id], role_name, split_kpath, role_name, split_kpath]
          end
        end
        relation = Relation.find(:first, :conditions => conditions)
        return nil unless relation
        if opts[:start]
          if relation.target_role == role_name
            relation.source = opts[:start]
          else
            relation.target = opts[:start]
          end
        elsif opts[:source]
          relation.source = opts[:source]
        else
          relation.target = opts[:target]
        end
        relation
      end
      
      def all_relations(start=nil)
        rel_as_source = Relation.find(:all, :conditions => ["site_id = ? AND source_kpath IN (?)", current_site[:id], split_kpath])
        rel_as_target = Relation.find(:all, :conditions => ["site_id = ? AND target_kpath IN (?)", current_site[:id], split_kpath])
        rel_as_source.each {|rel| rel.source = start } if start
        rel_as_target.each {|rel| rel.target = start } if start
        (rel_as_source + rel_as_target).sort {|a,b| a.other_role <=> b.other_role}
      end
    end
    

    module InstanceMethods
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
      
      def all_relations
        @all_relations ||= self.vclass.all_relations(self)
      end

      def relations_for_form
        all_relations.map {|r| [r.other_role.singularize, r.other_role]}
      end
      
      # List the links, grouped by role
      def relation_links
        res = []
        all_relations.each do |relation|
          #if relation.record_count > 5
          #  # FIXME: show message ?
          #end
          links = relation.records(:limit => 5, :order => "link_id DESC")
          res << [relation, links] if links
        end
        res
      end
      
      
      # Proxy to access user defined relations. The proxy is used to create/update links using the relation.
      #
      # Usage: node.relation_proxy(:role => 'news')
      def relation_proxy(opts={})
        opts = {:role => opts} unless opts.kind_of?(Hash)
        if role = opts[:role]
          if opts[:ignore_source]
            rel = Relation.find_by_role(role.singularize.underscore)
          else
            rel = Relation.find_by_role_and_kpath(role.singularize.underscore, self.vclass.kpath)
          end
          rel.start = self if rel
        elsif link = opts[:link]
          return nil unless link
          rel = Relation.find_by_id(link.relation_id)
          if rel
            rel.start = self
            if link.source_id == self[:id]
              rel.side = :source
            else
              rel.side = :target
            end
          end
        end
        rel
      end
      
      
      # REWRITE TO HERE
      
      private
      
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
        
        def destroy_links
          Link.find(:all, :conditions => ["source_id = ? OR target_id = ?", self[:id], self[:id]]).each do |l|
            l.destroy
          end
        end
        
        # shortcut accessors like tags_id = ...
        def method_missing(meth, *args)
          super
        rescue NoMethodError => err
          if meth.to_s =~ /^([\w_]+)_(ids?|zips?)(=?)$/
            role  = $1
            field = $2
            plural = ($2[-1..-1] == 's')
            mode = $3
            if rel = relation_proxy(:role => role, :ignore_source => true)
              if self.vclass.kpath =~ /\A#{rel.this_kpath}/
                if mode == '='
                  super if field[0..-2] == 'zip'
                  # add_link
                  set_relation(role,args[0])
                else
                  # get ids / zips
                  rel.send("other_#{field}")
                end
              elsif !args[0].empty?
                # bad relation for this class of object
                errors.add(role, "invalid for this class")
              end
            else
              # unknown relation
              errors.add(role, "unknown relation")
            end
          # we do not need this finder, zafu generates proper "do_find" methods.
          # elsif meth.to_s[-1..-1] != '=' && relation = relation_proxy(:role => meth.to_s)
          #   relation.unique? ? relation.record : relation.records
          else
            raise err # unknown relation
          end
        end
    end
  end
end

ActiveRecord::Base.send :include, Zena::Relations::HasRelations