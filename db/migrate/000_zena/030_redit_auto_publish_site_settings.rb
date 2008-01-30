class ReditAutoPublishSiteSettings < ActiveRecord::Migration
  def self.up
    add_column :sites, :auto_publish, :boolean
    add_column :sites, :redit_time, :datetime
    execute "UPDATE sites SET auto_publish=0"
    execute "UPDATE sites SET redit_time='0-0-0 0:0:30'"
  end

  def self.down
    drop_column :sites, :auto_publish
    drop_column :sites, :redit_time
  end
end
