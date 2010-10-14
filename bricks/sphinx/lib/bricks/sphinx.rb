require 'thinking_sphinx'

module Bricks
  module Sphinx
    module NodeClassMethods
      include Zena::Acts::Secure
      def search_text(query, opts = {})
        if offset = opts[:offset]
          limit = opts[:limit] || 20
          ids = search_for_ids(query, :with => with, :limit => (offset + limit) * [limit,20].max)
          return [] if ids.empty?
          # 1. filter with secure
          secure_ids = Zena::Db.fetch_ids("SELECT id FROM nodes WHERE #{secure_scope('nodes')} AND id IN (#{ids.join(',')})")
          # 2. reorder and apply offset
          if offset_ids = (ids & secure_ids)[offset..(offset + limit - 1)]
            # 3. populate
            records = Node.find(:all, :conditions => {:id => offset_ids})
            # 4. reorder
            offset_ids.map {|id| records.detect {|r| r.id == id }}
          else
            []
          end
        else
          if per_page = opts[:per_page]
            page = opts[:page].to_i
            page = 1 if page < 1
            search_records(query, :offset => (page - 1) * per_page, :limit => per_page)
          else
            search(query, opts).compact
          end
        end
      end
    end

    module NodeSearch
      def self.included(klass)
        klass.extend NodeClassMethods

        begin
          require 'thinking_sphinx/deltas/delayed_delta'
          ThinkingSphinx::Deltas::DelayedDelta
          has_dd = Bricks::CONFIG['worker']
        rescue LoadError
          has_dd = false
        end

        klass.class_eval do
          define_index do
            indexes zip

            Zena::Use::Fulltext::FULLTEXT_FIELDS.each do |fld|
              indexes versions.send(fld), :as => fld
            end

            has site_id

            where "versions.status >= #{Zena::Status[:pub]}"

            set_property :field_weights => { :idx_text_high => 5, :idx_text_medium => 3, :idx_text_low => 2 }
            set_property :group_concat_max_len => 30000 # FIXME: articles can easily have a length of 17000 chars...
            set_property :delta => (has_dd ? :delayed : true)
          end
        end

        klass.before_save :set_delta
      end

      private
        def set_delta
          self.delta = true
        end
    end # NodeSearch
  end # Sphinx
end # Bricks