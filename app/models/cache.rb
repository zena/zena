class Cache < ActiveRecord::Base
  cattr_accessor :perform_caching
  before_save    :set_site_id
  
  class << self
    
    def with(visitor_id, visitor_groups, kpath, *context)
      return yield unless perform_caching
      if cached = self.find(:first, :conditions => ["visitor_id = ? AND site_id = ? AND context = ?", visitor_id, visitor.site.id, context.join('.').hash.abs])
        cached[:content]
      else
        content = yield
        self.create(:visitor_id=>visitor_id, :visitor_groups=>".#{visitor_groups.join('.')}.", :kpath=>kpath,
                    :context=>context.join('.').hash.abs, :content=>content )
        content
      end
    end
    
    # We can provide a kpath selector for sweeping. If the kpath is in the cached scope, the cache is removed.
    def sweep(hash)
      if kpath  = hash[:kpath]
        klasses = []
        kpath.split(//).each_index { |i| klasses << kpath[0..i].inspect }
        kpath_selector = " AND kpath IN (#{klasses.join(',')})"
      else
        kpath_selector = ""
      end
      if hash[:visitor_id]
        self.connection.execute "DELETE FROM #{self.table_name} WHERE visitor_id = '#{hash[:visitor_id]}'" + kpath_selector
      end
      if hash[:visitor_groups]
        hash[:visitor_groups].each do |g|
          self.connection.execute "DELETE FROM #{self.table_name} WHERE visitor_groups LIKE '%.#{g}.%'" + kpath_selector
        end
      end
      if hash[:context]
        context = [hash[:context]].flatten.join('.').hash.abs
        self.connection.execute "DELETE FROM #{self.table_name} WHERE context = '#{context}'" + kpath_selector
      end
      if hash[:older_than]
        self.connection.execute "DELETE FROM #{self.table_name} WHERE updated_at < '#{hash[:older_than]}'" + kpath_selector
      end
    end
  end

  private
    def set_site_id
      self[:site_id] = visitor.site[:id]
    end
end
