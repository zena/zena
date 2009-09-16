=begin rdoc
= Cache html pages

This class is responsible for caching/expiring pages. It is called each time a web page is rendered and the visitor is anonymous.

=== Cache

When a CachedPage page is created, it stores the +content_data+ in the current site's static cache location and remembers the context used to create this page in order to expire it later. If passed +content_path+ it creates a symlink instead of a new file (used to cache documents, images).

=== Context

When the anonymous visitor visits a web page, it 'opens' many nodes in order to produce the final html. The nodes opened depend on the zafu template used. The list of opened nodes is stored as the cached page's context.

=== Expire

Whenever a node changes, all the cached pages which use this node as context are destroyed with their static files.

=== Example

Anonymous visits the node 'projects'. When rendering the html for this page, the following nodes are opened:
  projects ---> 11
  parent   ---> 1
  notes    ---> 12, 13, 39, 23, 82, 15
  hot      ---> 43, 23

The visited_nodes list is [11,1,12,13,39,23,82,15,43,23].

Later, joe edits one of the hot topics (id=43). As +43+ is in the context for the 'projects' page, the latter is expired.


= Cache rendered 'erb'

This class is also used for caching/expiring of rendered zafu templates (erb code).

=== Cached zafu

When a zafu template is rendered to erb code, the ids of the sub-templates used for this rendering (through 'include' tags) are stored in the join table 'cached_pages_nodes'. Whenever any of these sub-templates (including the master template) is updated, the rendered zafu is removed. This behavior is very close to CachedPage (caching of resulting html sent to clients).

=== Expire

Whenever a sub-template changes, all the rendered zafu templates in which this template was included are destroyed.

=== Example

Rendering 'Node_index.html' to erb includes the following sub-templates :
  Project.html ---> layout.html
               ---> notes.html

The visited_nodes list is [Node_index.html, Project.html, layout.html, notes.html].

Whenever any of the nodes listed above changes, 'Node_index.html' rendered folder is destroyed.
=end
class CachedPage < ActiveRecord::Base

  attr_protected :site_id
  cattr_accessor :perform_caching
  attr_accessor  :content_data, :content_path, :expire_with_ids
  validate       :cached_page_valid
  before_create  :clear_same_path
  after_save     :cached_page_after_save
  before_destroy :cached_page_on_destroy

  class << self

    # Expire all pages whose expire date is in the past
    def expire_old
      expire(CachedPage.find(:all, :conditions=>["expire_after < ?", Time.now]))
    end

    # Remove cached pages related to the given node.
    def expire_with(node, node_ids = nil)
      if node_ids && node_ids != []
        direct_pages = CachedPage.find(:all, :conditions => "node_id IN (#{node_ids.join(',')})")
      else
        direct_pages = []
      end
      expire(node.cached_pages + [])
    end

    private
      # Destroy cached pages
      def expire(pages)
        # tested in #MainController
        pages.each do |page|
          page.destroy
        end
      end
  end

  # Cached page's creation context (list of node ids).
  def node_ids
    self.class.fetch_ids("SELECT node_id FROM cached_pages_nodes WHERE cached_page_id = '#{self[:id]}'", 'node_id')
  end

  private
    def clear_same_path
      # in case the file was removed by hand or someting weird happened (see #166), clear
      CachedPage.connection.execute "DELETE cached_pages_nodes FROM cached_pages_nodes, cached_pages WHERE cached_pages_nodes.cached_page_id = cached_pages.id AND cached_pages.path = #{CachedPage.connection.quote(self[:path])} AND cached_pages.site_id = #{visitor.site[:id]}"
      CachedPage.connection.execute "DELETE FROM cached_pages WHERE cached_pages.path = #{CachedPage.connection.quote(self[:path])} AND cached_pages.site_id = #{visitor.site[:id]}"
    end

    def cached_page_valid
      errors.add('nodes', 'visited nodes empty, cannot create cache') unless @expire_with_ids || (visitor && visitor.visited_node_ids != [])
      self[:site_id] = visitor.site[:id]
    end

    def cached_page_after_save
      # create cache file
      filepath = "#{SITES_ROOT}#{path}"
      FileUtils.mkpath(File.dirname(filepath))
      if content_path
        FileUtils::rm(filepath) if File.exist?(filepath)
        File.symlink(content_path, filepath)
      else
        File.open(filepath, "wb+") { |f| f.write(content_data) }
      end

      # create join values from context for automatic expire
      if (ids = @expire_with_ids || visitor.visited_node_ids) != []
        values = ids.compact.uniq.map {|id| "(#{self[:id]}, #{id})"}.join(',')
        CachedPage.connection.execute "INSERT INTO cached_pages_nodes (cached_page_id, node_id) VALUES #{values}"
      end
    end

    # When destroying a cache record, remove the related cached file.
    def cached_page_on_destroy
      filepath = "#{SITES_ROOT}#{path.gsub('..','')}" # just in case...
      CachedPage.logger.info "remove #{filepath}"
      FileUtils::rm(filepath) if File.exist?(filepath)
      CachedPage.connection.execute "DELETE FROM cached_pages_nodes WHERE cached_page_id = '#{id}'"
    end
end
