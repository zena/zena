class AddMasterIdToSite < ActiveRecord::Migration
  def self.up
    add_column :sites, :master_id, :integer
  end

  def self.down
    remove_column :sites, :master_id
  end
end
