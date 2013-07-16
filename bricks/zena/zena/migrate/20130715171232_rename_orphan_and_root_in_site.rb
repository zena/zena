class RenameOrphanAndRootInSite < ActiveRecord::Migration
  def self.up
    rename_column :sites, :root_id,   :home_id
    rename_column :sites, :orphan_id, :root_id
  end

  def self.down
    rename_column :sites, :root_id, :orphan_id
    rename_column :sites, :home_id, :root_id
  end
end
