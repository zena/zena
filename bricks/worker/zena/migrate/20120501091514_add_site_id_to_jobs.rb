class AddSiteIdToJobs < ActiveRecord::Migration
  def self.up
    add_column :delayed_jobs, :site_id, :integer
  end

  def self.down
    drop_column :delayed_jobs, :site_id
  end
end
