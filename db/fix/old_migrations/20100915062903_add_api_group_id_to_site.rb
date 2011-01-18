class AddApiGroupIdToSite < ActiveRecord::Migration
  def self.up
    add_column :sites, :api_group_id, :integer
  end

  def self.down
    remove_column :sites, :api_group_id
  end
end
