class RemoveDefaults < ActiveRecord::Migration
  def self.up
    change_column :groups_users, :group_id, :integer, :default => nil
    change_column :groups_users,  :user_id, :integer, :default => nil
    change_column :nodes,         :user_id, :integer, :default => nil
    change_column :links,       :source_id, :integer, :default => nil
    change_column :links,       :target_id, :integer, :default => nil
    change_column :versions,      :node_id, :integer, :default => nil
    change_column :versions,      :user_id, :integer, :default => nil
    
  end

  def self.down
    change_column :groups_users, :group_id, :integer, :default => 0
    change_column :groups_users,  :user_id, :integer, :default => 0
    change_column :nodes,         :user_id, :integer, :default => 0
    change_column :links,       :source_id, :integer, :default => 0
    change_column :links,       :target_id, :integer, :default => 0
    change_column :versions,      :node_id, :integer, :default => 0
    change_column :versions,      :user_id, :integer, :default => 0
  end
end