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
              :order  => 'zip ASC' )
          elsif !query.blank?
            match = sanitize_sql(["vs.idx_text_high LIKE ?", "%#{query.gsub('*','%')}%"])
            select = "nodes.*"

            case Zena::Db.adapter
            when 'postgresql'
              select = "DISTINCT ON (nodes.zip) #{select}"
              group  = nil
            else
              group = 'nodes.id'
            end

            return options.merge(
              :select => select,
              :joins  => "INNER JOIN versions AS vs ON vs.node_id = nodes.id AND vs.status >= #{Zena::Status[:pub]}",
              :conditions => match,
              :group      => group,
              :order  => "zip DESC") # new items first
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
            # Removed pagination clause or no pagination
            if query.kind_of?(Hash)
              search_index(query, options)
            else
              # TODO: should we parse :_find (all, first, count) here ?
              search_text(query, options)
            end
          end
        end

        # Execute an index search using query builder. Either provide a full query with 'qb' or 'key'='value' parameters.
        def search_index(params, options = {})
          count   = (params.delete(:_find) || :all).to_sym
          node    = options.delete(:node) || current_site.root_node
          default = options.delete(:default)

          unless query = params[:qb]
            query_args = []

            params.each do |key, value|
              query_args << "#{key} = #{Zena::Db.quote(value)}"
            end

            query = "nodes where #{query_args.join(' and ')} in site"
          end

          res = node.find(count, query, options.merge(:errors => true, :rubyless_helper => self, :default => default))

          if res.kind_of?(::QueryBuilder::Error)
            raise ::QueryBuilder::Error.new("Error parsing query #{query.inspect} (#{res.message})")
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
            # :default argument not used here
            options.delete(:default)
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
        #   out "<% set_#{pagination_key}_count = (set_#{pagination_key}_nodes / @search_per_page).ceil; set_#{pagination_key} = [1,params[:page].to_i].max %>"
        #   out "<% #{node_count} = @search_count; #{page_count} = (#{node_count} / @search_per_page).ceil; #{curr_page} = [1,params[:#{pagination_key}].to_i].max %>"
        #   expand_if....
        # end
      end
    end # Search
  end # Use
end # Zena