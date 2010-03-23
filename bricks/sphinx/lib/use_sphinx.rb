require 'thinking_sphinx'

module Bricks
  module Sphinx
    module NodeClassMethods
      include Zena::Acts::Secure
      def search_records(query, opts = {})
        with = opts[:with] || {}
        with[:site_id] = current_site.id
        if offset = opts[:offset]
          limit = opts[:limit] || 20
          ids = search_for_ids(query, :with => with, :limit => (offset + limit) * [limit,20].max)
          return [] if ids.empty?
          # 1. filter with secure
          secure_ids = Zena::Db.fetch_ids("SELECT id FROM nodes WHERE id IN (#{ids.join(',')}) AND #{secure_scope('nodes')}")
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
            indexes name
            indexes versions.title,                    :as => 'title'
            indexes versions.text,                     :as => 'text'
            indexes versions.summary,                  :as => 'summary'
            indexes versions.dynamic_attributes.value, :as => 'attribute'
            #indexes versions.dynamic_attributes.key,   :as => 'key'

            has site_id

            where "versions.status >= #{Zena::Status[:pub]}"

            set_property :field_weights => { :title => 5, :summary => 3, :text => 2, :attribute => 1 }
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