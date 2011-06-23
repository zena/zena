class FixCachedPathIndex < ActiveRecord::Migration
  def self.up
    remove_index "cached_pages", :name => "index_cached_pages_on_path_and_site_id" rescue nil
    change_column :cached_pages, :path, :string
    add_index "cached_pages", ["path", "site_id"], :name => "index_cached_pages_on_path_and_site_id"
  end

  def self.down
  end
end
