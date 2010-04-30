module Bricks
  module Tags
    class StringHash
      include RubyLess
      safe_context [:[], String] => String
      safe_method :keys => [String]
    end

    module HasTags
      # this is called when the module is included into the 'base' module
      def self.included(base)
        base.extend Bricks::Tags::TriggerClassMethod
      end
    end

    module TriggerClassMethod
      def has_tags
        after_save    :update_tags
        safe_context  :tags => ['Link']
        safe_method   :tag_list => String, :tag => String, :tagged => StringHash, :tag_names => [String]

        class_eval <<-END
          include Bricks::Tags::InstanceMethods
          class << self
            include Bricks::Tags::ClassMethods
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

      def tagged
        @tagged ||= Hash[*tag_names.map {|t| [t,t]}.flatten]
      end

      # Set/unset a named tag
      def tagged=(hash)
        # named tags
        hash.each do |k, v|
          if v.empty?
            remove_tag(k.to_s)
          else
            add_tag(k.to_s)
          end
        end
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
            add_tags = tags_to_add.map{|t| [self[:id], Link.connection.quote(t)]}
            Zena::Db.insert_many('links', %W{source_id comment}, add_tags)
          end
          remove_instance_variable(:@tags) if @tags
          @tag_names = nil
        end

    end
  end
end

ActiveRecord::Base.send :include, Bricks::Tags::HasTags
