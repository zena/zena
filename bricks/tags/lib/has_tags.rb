module Zena
  module Tags
    module HasTags
      # this is called when the module is included into the 'base' module
      def self.included(base)
        base.extend Zena::Tags::TriggerClassMethod
      end
    end

    module TriggerClassMethod
      def has_tags
        after_save    :update_tags
        zafu_context  :tags => ["Link"]
        zafu_readable :name, :tag_list, :tag
        
        class_eval <<-END
          include Zena::Tags::InstanceMethods
          class << self
            include Zena::Tags::ClassMethods
          end
        END
      end
    end
    
    module ClassMethods
      
    end
    
    module InstanceMethods
      
      def l_tag
        l_comment
      end
      
      # Used by multiversion to remove attributes with same value.
      def tag
        nil
      end
      
      # Add a new tag
      def tag=(v)
        tag_names_to_add, tag_names_to_remove = [], []
        tags_as_list(v).each do |t|
          if t[0..0] == '-'
            remove_tag(t[1..-1])
          else
            add_tag(t)
          end
        end
      end
      
      # String listing the tags separated by a comma.
      def tag_list
        tag_names.join(', ')
      end
      
      # Define tag list from a comma separated list of tag names.
      def tag_list=(v)
        @tag_names = tags_as_list(v)
      end
      
      # List of tag names.
      def tag_names
        @tag_names ||= (tags || []).map {|t| t[:comment]}
      end
      
      # List of Links that are tags for the current node.
      def tags
        return @tags if defined?(@tags)
        @tags = begin
          tags = Link.find(:all, :conditions => ["source_id = ? AND target_id IS NULL", self[:id]], :order => "comment ASC")
          tags.each do |t|
            t.start = self
          end
          tags == [] ? nil : tags
        end
      end
      
      def add_tag(name)
        return if tag_names.include?(name)
        @tag_names << name
      end
      
      def remove_tag(name)
        self.tag_names.delete(name)
      end
      
      # Overwrite 'remove_link' from 'has_relations'
      def remove_link(link)
        if link[:source_id] != self[:id] && link[:target_id] != self[:id]
          errors.add('link', "not related to this node")
          return false
        end
        if link[:relation_id]
          # find proxy
          if rel = relation_proxy_from_link(link)
            rel.remove_link(link)
          else
            errors.add('link', "cannot remove (relation proxy not found).")
          end
        else
          # tag
          @del_tags ||= []
          @del_tags << link
        end
      end
      
      
      private
        
        def tags_as_list(str)
          str.split(',').map(&:strip).reject{|t| t.blank? }
        end
        
        # Update/create links defined in relation proxies
        def update_tags
          return unless @tag_names
          old_tag_names = (self.tags || []).map {|t| t[:comment]}
          
          tags_to_add = @tag_names - old_tag_names
          tags_to_del = []
          (self.tags || []).each do |t|
            tags_to_del << t unless @tag_names.include?(t[:comment])
          end
          
          if tags_to_del != []
            del_ids = tags_to_del.map {|t| t[:id]}
            Link.connection.execute "DELETE FROM links WHERE id IN (#{del_ids.join(',')})"
          end
          
          if tags_to_add != []
            add_tags = tags_to_add.map{|t| "(#{self[:id]}, #{t.inspect})"}
            Link.connection.execute "INSERT INTO links (source_id, comment) VALUES #{add_tags.join(',')}"
          end
          remove_instance_variable(:@tags) if @tags
          @tag_names = nil
        end
        
    end
  end
end

ActiveRecord::Base.send :include, Zena::Tags::HasTags
