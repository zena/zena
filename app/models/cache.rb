class Cache < ActiveRecord::Base
  class << self
    def perform_caching
      ApplicationController.perform_caching
    end
    def with(user_id, group_ids, kpath, *context)
      return yield unless perform_caching
      if cached = self.find_by_user_id_and_context(user_id,context.join('.'))
        Cache.logger.info "=============== CACHED #{context.join('.')}"
        cached.content
      else
        Cache.logger.info "=============== RENDER #{context.join('.')}"
        content = yield
        self.create(:user_id=>user_id, :group_ids=>".#{group_ids.join('.')}.", :kpath=>kpath,
                    :context=>context.join('.'), :content=>content )
        content
      end
    end
    
    # We can provide a kpath selector for sweeping. If the kpath is in the cached scope, the cache is removed.
    def sweep(hash)
      Cache.logger.info "=============== SWEEP #{hash.inspect}"
      if hash[:kpath]
        kpath_selector = " AND left('#{hash[:kpath]}',length(kpath)) = kpath "
      else
        kpath_selector = ""
      end
      if hash[:user_id]
        self.connection.execute "DELETE FROM #{self.table_name} WHERE user_id = '#{hash[:user_id]}'" + kpath_selector
      end
      if hash[:group_ids]
        hash[:group_ids].each do |g|
          self.connection.execute "DELETE FROM #{self.table_name} WHERE group_ids LIKE '%.#{g}.%'" + kpath_selector
        end
      end
      if hash[:context]
        context = [hash[:context]].flatten.join('.')
        self.connection.execute "DELETE FROM #{self.table_name} WHERE context = '#{context}'" + kpath_selector
      end
      if hash[:older_than]
        self.connection.execute "DELETE FROM #{self.table_name} WHERE updated_at < '#{hash[:older_than]}'" + kpath_selector
      end
    end
  end   
end
