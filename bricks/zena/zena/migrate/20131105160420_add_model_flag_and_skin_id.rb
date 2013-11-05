class AddModelFlagAndSkinId < ActiveRecord::Migration
  def self.up
    add_column :users, :is_model, :boolean
    add_column :sites, :skin_id, :integer
  end

  def self.down
    remove_column :users, :is_model
    remove_column :sites, :skin_id
  end
end
