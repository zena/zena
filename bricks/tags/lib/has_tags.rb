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
        zafu_readable :name, :tag_list
        safe_attribute :tag
        
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
        add_tags(v)
      end
      
      # String listing the tags separated by a comma.
      def tag_list
        tag_names.join(', ')
      end
      
      # Define tag list from a comma separated list of tag names.
      def tag_list=(v)
        tags_as_list = self.tags_as_list(v)

        tags_to_add = tags_as_list - tag_names
        unless tags_to_add == []
          @add_tags = ((@add_tags || []) + tags_to_add).uniq
        end

        tags_names_to_del = tag_names - tags_as_list
        tags_to_del       = []
        tags.each do |t|
          tags_to_del << t if tags_names_to_del.include?(t[:comment])
        end
        unless tags_to_del == []
          @del_tags = ((@del_tags || []) + tags_to_del).uniq
        end
      end
      
      # List of tag names.
      def tag_names
        @tag_names ||= tags.map {|t| t[:comment]}
      end
      
      # List of Links that are tags for the current node.
      def tags
        @tags ||= Link.find(:all, :conditions => ["source_id = ? AND target_id IS NULL", self[:id]], :order => "comment ASC")
      end
      
      def add_tags(tags)
        tags_to_add = tags_as_list(tags) - tag_names
        return if tags_to_add == []
        @add_tags = ((@add_tags || []) + tags_to_add).uniq
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
          return unless @add_tags || @del_tags
          if @del_ids
            del_ids = @del_tags.map {|t| t[:id]}
            Link.connection.execute "DELETE FROM links WHERE id IN (#{del_ids.join(',')})"
          end
          if @add_tags
            add_tags = @add_tags.map{|t| "(#{self[:id]}, #{t.inspect})"}
            Link.connection.execute "INSERT INTO links (source_id, comment) VALUES #{add_tags.join(',')}"
          end
          @add_tags = nil
          @del_tags = nil
        end
        
    end
  end
end

ActiveRecord::Base.send :include, Zena::Tags::HasTags
