class AddMasterIdToSite < ActiveRecord::Migration
  def self.up
    add_column :sites, :master_id, :integer
    # The id of the node without parent
    add_column :sites, :orphan_id, :integer
    execute "UPDATE sites SET orphan_id = root_id"
  end

  def self.down
    remove_column :sites, :master_id
    remove_column :sites, :orphan_id
  end
end
