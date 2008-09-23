class RemoveMonolingualSiteOption < ActiveRecord::Migration
  def self.up
    remove_column :sites, :monolingual
  end

  def self.down
    add_column :sites, :monolingual, :boolean
  end
end
