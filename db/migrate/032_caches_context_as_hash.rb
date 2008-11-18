class CachesContextAsHash < ActiveRecord::Migration
  def self.up
    execute "DELETE FROM caches"
    change_column :caches, :context, :integer
  end

  def self.down
    change_column :caches, :context, :string, :limit => 200
  end
end
