module Zena
  module Relations
    LINK_ATTRIBUTES = [:status, :comment, :date]
    LINK_REGEXP = /^([\w_]+)_(ids?|zips?|#{LINK_ATTRIBUTES.join('|')})(=?)$/
    
    module HasRelations
      # this is called when the module is included into the 'base' module
      def self.included(base)
        base.extend Zena::Relations::TriggerClassMethod
      end
    end

    module TriggerClassMethod
      def has_relations
        validate      :relations_valid
        after_save    :update_relations
        after_destroy :destroy_links
        zafu_readable :link
        zafu_readable(*LINK_ATTRIBUTES.map {|k| "l_#{k}".to_sym})
        
        include Zena::Relations::InstanceMethods
        
        class_eval <<-END
          class << self
            include Zena::Relations::ClassMethods
          end
          
          def relation_base_class
            #{self}
          end
          
          HAS_RELATIONS = true
        END
      end
    end
    
    module ClassMethods
      # All relations related to the current class/virtual_class with its ancestors.
      def all_relations(start=nil)
        rel_as_source = RelationProxy.find(:all, :conditions => ["site_id = ? AND source_kpath IN (?)", current_site[:id], split_kpath])
        rel_as_target = RelationProxy.find(:all, :conditions => ["site_id = ? AND target_kpath IN (?)", current_site[:id], split_kpath])
        rel_as_source.each {|rel| rel.source = start } if start
        rel_as_target.each {|rel| rel.target = start } if start
        (rel_as_source + rel_as_target).sort {|a,b| a.other_role <=> b.other_role}
      end
      
      # Class path hierarchy. Example for (Post) : N, NN, NNP
      def split_kpath
        @split_kpath ||= begin
          klasses   = []
          kpath.split(//).each_index { |i| klasses << kpath[0..i] } 
          klasses
        end
      end
    end
    
    module InstanceMethods
      def set_link(link)
        @link = link
      end
      
      # Linked_node is a way to store a linked node during calendar display or ajax return
      # calls so the template knows which "couple" has just been formed or removed.
      # The linked_node "node" must respond to "l_date".
      def linked_node=(node)
        @linked_node = node
      end
      
      def linked_node
        @linked_node ||= @relation_proxies ? @relation_proxies[@relation_proxies.keys.first].last_target : nil
      end
      
      # status defined through loading link
      def l_status
        return @l_status if defined? @l_status
        val = @link ? @link[:status] : self['l_status']
        val ? val.to_i : nil
      end
      
      # TODO: could we use LINK_ATTRIBUTES and 'define_method' here ?
      
      # comment defined through loading link
      def l_comment
        return @l_comment if defined? @l_comment
        @link ? @link[:comment] : self['l_comment']
      end
      
      # date defined through loading link
      def l_date
        return @l_date if defined? @l_date
        @l_date = @link ? @link[:date] : (self['l_date'] ? Time.parse(self['l_date']) : nil)
      end
      
      def link_id
        @link ? @link[:id] : (self[:link_id] == -1 ? nil : self[:link_id]) # -1 == dummy link
      end
      
      def link_id=(v)
        if @link && @link[:id].to_i != v.to_i
          @link = nil
        end
        self[:link_id] = v.to_i
        if @link_attributes_to_update
          if rel = relation_proxy_from_link
            @link_attributes_to_update.each do |k,v|
              rel.send("other_#{k}=",v)
            end
          end
        end 
      end
      
      # FIXME: this method does an 'update' not only 'add'
      def add_link(role, hash)
        if rel = relation_proxy(role)
          LINK_ATTRIBUTES.each do |k|
            rel.send("other_#{k}=", hash[k]) if hash.has_key?(k)
          end
          rel.other_id = hash[:other_id] if hash.has_key?(:other_id)
        else
          errors.add(role, 'invalid relation')
        end
      end
      
      def remove_link(link)
        if link[:source_id] != self[:id] && link[:target_id] != self[:id]
          errors.add('link', "not related to this node")
          return false
        end
        # find proxy
        if rel = relation_proxy_from_link(link)
          rel.remove_link(link)
        else
          errors.add('link', "cannot remove (relation proxy not found).")
        end
      end
      
      # TODO: could use rails native nested attributes !!!
      def link=(hash)
        return unless hash.kind_of?(Hash)
        hash.each do |role, definition|
          if role =~ /\A\d+\Z/
            # key used as array
          else
            # key used as role
            definition['role'] ||= role
          end
          add_link(definition.delete('role'), definition.symbolize_keys)  # TODO: only use string keys
        end 
      end
      
      def link
        @link
      end
      
      def l_comment=(v)
        @l_comment = v.blank? ? nil : v
        if rel = relation_proxy_from_link
          rel.other_comment = @l_comment
        end
      end
      
      def l_status=(v)
        @l_status = v.blank? ? nil : v
        if rel = relation_proxy_from_link
          rel.other_status = @l_status
        end
      end
      
      def l_date=(v)
        @l_date = v.blank? ? nil : v
        if rel = relation_proxy_from_link
          rel.other_date = @l_date
        end
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
        all_relations.each do |rel|
          #if relation.record_count > 5
          #  # FIXME: show message ?
          #end
          links = rel.records(:limit => 5, :order => "link_id DESC")
          res << [rel, links] if links
        end
        res
      end
      
      # Find relation proxy for the given role.
      def relation_proxy(role)
        @relation_proxies ||= {}
        return @relation_proxies[role] if @relation_proxies.has_key?(role)
        @relation_proxies[role] = RelationProxy.get_proxy(self, role.singularize.underscore)
      end
      
      def relation_proxy_from_link(link = nil)
        unless link
          if @link
            link = @link
          elsif self.link_id
            link = @link = Link.find_through(self, self.link_id)
          end
          return nil unless link
        end
        @relation_proxies ||= {}
        return @relation_proxies[link.role] if @relation_proxies.has_key?(link.role)
        @relation_proxies[link.role] = link.relation_proxy(self)
      end
      
      private
      
        # Used to create / destroy / update links through pseudo methods 'icon_id=', 'icon_status=', ...
        # Pseudo methods created for a many-to-one relation (icon_for --- icon):
        # icon_id=::      set icon
        # icon_status=::  set status field for link to icon
        # icon_comment=:: set comment field for link to icon
        # icon_for_ids=:: set all nodes for which the image is an icon (replaces old values)
        # icon_for_id=::  add a node for which the image is an icon (adds a new value)
        # icon_id::       get icon id
        # icon_zip::      get icon zip
        # icon_status::   get status field for link to icon
        # icon_comment::  get comment field for link to icon
        # icon_for_ids::  get all node ids for which the image is an icon
        # icon_for_zips:: get all node zips for which the image is an icon
        def method_missing(meth, *args)
          # first try rails' version of method missing
          super
        rescue NoMethodError => err
          # 1. is this a method related to a relation ?
          if meth.to_s =~ LINK_REGEXP
            role  = $1
            field = $2
            mode  = $3
            # 2. is this a valid role ?
            if rel = relation_proxy(role)
              if mode == '='
                # set
                case field
                when 'zip', 'zips'
                  # not used to set relations (must use 'translate_attributes' to chagen zip into id before call)
                  raise err
                end
                # set value
                rel.send("other_#{field}=", args[0])
              else
                # get
                if field != 'ids' && field != 'zips' && !rel.unique?
                  # ask for a single value in a ..-to-many relation
                  # 1. try to use focus
                  if @link
                    rel.other_link = @link
                  elsif self.link_id
                    @link = Link.find_through(self, self.link_id)
                    rel.other_link = @link
                  else
                    return nil
                  end
                end
                rel.send("other_#{field}")
              end
            else
              # invalid relation
              if mode == '='
                errors.add(role, "invalid relation") unless args[0].blank?
                return args[0]
              else
                # ignore
                return nil
              end
            end
          else
            # not related to relations
            raise err
          end
        end
      
        # Make sure all updated relation proxies are valid
        def relations_valid
          return true unless @relation_proxies
          @relation_proxies.each do |role, rel|
            next unless rel
            unless rel.attributes_to_update_valid?
              errors.add(role, rel.link_errors.join(', '))
            end
          end
        end
        
        # Update/create links defined in relation proxies
        def update_relations
          return unless @relation_proxies
          @relation_proxies.each do |role, rel|
            next unless rel
            rel.update_links!
          end
        end
        
        # Destroy all links related to this node
        def destroy_links
          Link.find(:all, :conditions => ["source_id = ? OR target_id = ?", self[:id], self[:id]]).each do |l|
            l.destroy
          end
        end
    end
  end
end

ActiveRecord::Base.send :include, Zena::Relations::HasRelations
