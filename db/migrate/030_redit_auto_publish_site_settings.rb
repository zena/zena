class ReditAutoPublishSiteSettings < ActiveRecord::Migration
  def self.up
    add_column :sites, :auto_publish, :boolean
    add_column :sites, :redit_time, :integer
    execute "UPDATE sites SET auto_publish = false"
    execute "UPDATE sites SET redit_time = '7200'" # 2 hours
  end

  def self.down
    remove_column :sites, :auto_publish
    remove_column :sites, :redit_time
  end
end
