module Bricks
  module Tags
    module Zafu
      def r_tag_cloud
        if node_kind_of?(Node)
          node_name = @context[:parent_node] || node
        else
          node_name = @context[:previous_node]
        end

        if @params[:in] == 'project' || @params[:in] == 'section'
          filter = " AND nodes.project_id = \#{Node.connection.quote(#{node_name}.get_#{@params[:in]}_id)}"
        else
          filter = ''
        end

        method = "Link.find_by_sql(%Q{SELECT COUNT(nodes.id) AS count, links.comment FROM links INNER JOIN nodes ON nodes.id = links.source_id WHERE \#{@node.secure_scope('nodes')} AND links.target_id IS NULL#{filter} GROUP BY links.comment ORDER BY links.comment})"
        open_context(:method => method, :class => [Link])
      end
    end # Zafu
  end # Tags
end # Bricks