class CachesContextAsHash < ActiveRecord::Migration
  def self.up
    execute "DELETE FROM caches"
    remove_column :caches, :context
    add_column :caches, :context, :integer
  end

  def self.down
    remove_column :caches, :context
    add_column :caches, :context, :string, :limit => 200
  end
end
