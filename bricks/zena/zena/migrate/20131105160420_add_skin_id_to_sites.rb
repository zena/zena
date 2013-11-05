class AddSkinIdToSites < ActiveRecord::Migration
  def self.up
    add_column :sites, :skin_id, :integer
  end

  def self.down
    remove_column :sites, :skin_id
  end
end
