module Zena
  module Use
    module Search
      module NodeClassMethods
        # Return a hash to do a fulltext query.
        def match_query(query, options = {})
          node = options.delete(:node)
          if query == '.' && node
            return options.merge(
              :conditions => ["parent_id = ?",node[:id]],
              :order  => 'node_name ASC' )
          elsif !query.blank?
            if Zena::Db.adapter == 'mysql' && RAILS_ENV != 'test'
              match  = sanitize_sql(["MATCH (vs.idx_text_high,vs.idx_text_medium,vs.idx_text_low) AGAINST (?) OR nodes.node_name LIKE ?", query, "#{options[:name_query] || query.url_name}%"])
              select = sanitize_sql(["nodes.*, MATCH (vs.idx_text_high,vs.idx_text_medium,vs.idx_text_low) AGAINST (?) + (5 * (nodes.node_name LIKE ?)) AS score", query, "#{query}%"])
            else
              match = sanitize_sql(["nodes.node_name LIKE ?", "#{query}%"])
              select = "nodes.*, #{match} AS score"
            end

            return options.merge(
              :select => select,
              :joins  => "INNER JOIN versions AS vs ON vs.node_id = nodes.id AND vs.status >= #{Zena::Status[:pub]}",
              :conditions => match,
              :group      => "nodes.id",
              :order  => "score DESC, zip ASC")
          else
            # error
            return options.merge(:conditions => '0')
          end
        end

        def search_records(query, options = {})
          if per_page = options.delete(:per_page)
            page = options.delete(:page).to_i
            page = 1 if page < 1
            search_records(query, options.merge(:offset => (page - 1) * per_page, :limit => per_page))
          else
            # Removed pagination clause
            if query.kind_of?(Hash)
              search_index(query, options)
            else
              search_text(query, options)
            end
          end
        end

        # Execute an index search using query builder. Either provide a full query with 'qb' or 'key'='value' parameters.
        def search_index(params, options = {})
          query = ::QueryBuilder::Query.new(Node.query_compiler)
          query.add_table(query.main_table)
          filters = []

          unless query = params[:qb]
            query_args = []

            params.each do |key, value|
              query_args << "#{key} = #{Zena::Db.quote(value)}"
            end

            query = "nodes where #{query_args.join(' and ')} in site"
          end

          res = current_site.root_node.find(:all, query, :errors => true, :rubyless_helper => self)

          if res.kind_of?(Exception)
            raise ActiveRecord::StatementInvalid.new("Error parsing query #{query.inspect} (#{res.message})")
          else
            return res
          end
        end

        # Execute a fulltext search using default fulltext support from the database (MyISAM on MySQL).
        def search_text(query, options = {})
          if offset = options[:offset]
            limit = options[:limit] || 20
            Node.find(:all, match_query(query).merge(:offset => offset, :limit => limit))
          else
            Node.find(:all, match_query(query, options))
          end
        end
      end # NodeClassMethods

      module ZafuMethods
        include RubyLess
        safe_method :search_results => {:class => [Node], :nil => true, :method => '@nodes'}

        # def r_search_results
        #   pagination_key = 'page'
        #   set_context_var('paginate', 'key', pagination_key)
        #
        #   node_count = get_var_name('paginate', 'nodes')
        #   page_count = get_var_name('paginate', 'count')
        #   curr_page  = get_var_name('paginate', 'current')
        #   out "<% set_#{pagination_key}_count = (set_#{pagination_key}_nodes / @search_per_page).ceil; set_#{pagination_key} = [1,params[:page].to_i].max -%>"
        #   out "<% #{node_count} = @search_count; #{page_count} = (#{node_count} / @search_per_page).ceil; #{curr_page} = [1,params[:#{pagination_key}].to_i].max -%>"
        #   expand_if....
        # end
      end
    end # Search
  end # Use
end # Zena