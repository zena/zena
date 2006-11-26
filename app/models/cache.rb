class Cache < ActiveRecord::Base
  class << self
    def with(user_id, group_ids, *context)
      if cached = self.find_by_user_id_and_context(user_id,context.join('.'))
        cached.content
      else
        content = yield
        self.create(:user_id=>user_id, :group_ids=>".#{group_ids.join('.')}.", :content=>content, :context=>context.join('.'))
        content
      end
    end
    
    def sweep(hash)
      if hash[:user_id]
        self.connection.execute "DELETE FROM #{self.table_name} WHERE user_id = '#{hash[:user_id]}'"
      end
      if hash[:group_ids]
        hash[:group_ids].each do |g|
          self.connection.execute "DELETE FROM #{self.table_name} WHERE group_ids LIKE '%.#{g}.%'"
        end
      end
      if hash[:context]
        context = [hash[:context]].flatten.join('.')
        self.connection.execute "DELETE FROM #{self.table_name} WHERE context = '#{context}'"
      end
      if hash[:older_than]
        self.connection.execute "DELETE FROM #{self.table_name} WHERE updated_at < '#{hash[:older_than]}'"
      end
    end
  end   
end
