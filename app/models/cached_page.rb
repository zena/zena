class CachedPage < ActiveRecord::Base
  has_and_belongs_to_many :nodes
  before_destroy :cached_page_on_destroy
  class << self
    def perform_caching
      # we check for const definition for calls from rake/console/etc
      Module.const_defined?(:ApplicationController) ? ApplicationController.perform_caching : false
    end
    
    def expire_old
      expire(CachedPage.find(:all, :conditions=>["expire_after > ?", Time.now]))
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
