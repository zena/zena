module Zena
  module Use
    module Search
      module NodeClassMethods
        # Return a hash to do a fulltext query.
        def match_query(query, opts={})
          node = opts.delete(:node)
          if query == '.' && node
            return opts.merge(
              :conditions => ["parent_id = ?",node[:id]],
              :order  => 'name ASC' )
          elsif !query.blank?
            if Zena::Db.adapter == 'mysql' && RAILS_ENV != 'test'
              match  = sanitize_sql(["MATCH (vs.title,vs.text,vs.summary) AGAINST (?) OR nodes.name LIKE ?", query, "#{opts[:name_query] || query.url_name}%"])
              select = sanitize_sql(["nodes.*, MATCH (vs.title,vs.text,vs.summary) AGAINST (?) + (5 * (nodes.name LIKE ?)) AS score", query, "#{query}%"])
            else
              match = sanitize_sql(["nodes.name LIKE ?", "#{query}%"])
              select = "nodes.*, #{match} AS score"
            end

            return opts.merge(
              :select => select,
              :joins  => "INNER JOIN versions AS vs ON vs.node_id = nodes.id AND vs.status >= #{Zena::Status[:pub]}",
              :conditions => match,
              :group      => "nodes.id",
              :order  => "score DESC, zip ASC")
          else
            # error
            return opts.merge(:conditions => '0')
          end
        end

        def search_records(query, opts={})
          with = opts[:with] || {}
          with[:site_id] = current_site.id
          if offset = opts[:offset]
            limit = opts[:limit] || 20
            Node.find(:all, match_query(query).merge(:offset => offset, :limit => limit))
          else
            if per_page = opts[:per_page]
              page = opts[:page].to_i
              page = 1 if page < 1
              search_records(query, :offset => (page - 1) * per_page, :limit => per_page)
            else
              Node.find(:all, match_query(query, opts))
            end
          end
        end
      end # NodeClassMethods
    end # Search
  end # Use
end # Zena