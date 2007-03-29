=begin rdoc
This class is responsible for caching/expiring pages. It is called each time a web page is rendered and the visitor is anonymous.

=== Cache

When a CachedPage page is created, it stores the +cache_content+ in the current site's static cache location and remembers the context used to create this page in order to expire it later.

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
=end
class CachedPage < ActiveRecord::Base
  attr_accessor :cache_content
  has_and_belongs_to_many :nodes
  validate       :cached_page_valid
  after_save     :cached_page_after_save
  before_destroy :cached_page_on_destroy
  class << self
    
    # Return true if we are currently performing caching
    def perform_caching
      # we check for const definition for calls from rake/console/etc
      defined?(:ApplicationController) ? ApplicationController.perform_caching : false
    end
    
    # Expire all pages whose expire date is in the past
    def expire_old
      expire(CachedPage.find(:all, :conditions=>["expire_after < ?", Time.now]))
    end
    
    # Remove cached pages related to the given node.
    def expire_with(node)
      expire(node.cached_pages)
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
    def cached_page_valid
      errors.add('nodes', 'visited nodes empty, cannot create cache') unless visitor && visitor.visited_node_ids != []
      self[:site_id] = visitor.site[:id]
    end
  
    def cached_page_after_save
      # create cache file
      filepath = "#{SITES_ROOT}#{path}"
      FileUtils.mkpath(File.dirname(filepath))
      File.open(filepath, "wb+") { |f| f.write(cache_content) }
    
      # create join values from context for automatic expire
      values = visitor.visited_node_ids.uniq.map {|id| "(#{self[:id]}, #{id})"}.join(',')
      CachedPage.connection.execute "INSERT INTO cached_pages_nodes (cached_page_id, node_id) VALUES #{values}"
    end
  
    # When destroying a cache record, remove the related cached file.
    def cached_page_on_destroy
      filepath = "#{SITES_ROOT}#{path.gsub('..','')}" # just in case...
      CachedPage.logger.info "remove #{filepath}"
      if File.exist?(filepath)
        FileUtils::rm(filepath)
      end
      CachedPage.connection.execute "DELETE FROM cached_pages_nodes WHERE cached_page_id = '#{id}'"
    end
end
