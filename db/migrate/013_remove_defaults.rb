class RemoveDefaults < ActiveRecord::Migration
  def self.up
    change_column :groups_users, :group_id, :integer, :default => nil
    change_column :groups_users,  :user_id, :integer, :default => nil
    change_column :nodes,         :user_id, :integer, :default => nil
    change_column :links,       :source_id, :integer, :default => nil
    change_column :links,       :target_id, :integer, :default => nil
    change_column :versions,      :node_id, :integer, :default => nil
    change_column :versions,      :user_id, :integer, :default => nil

    # change allow nil
    change_column :versions,       :status, :integer, :default => 30, :null => false
    change_column :versions,       :number, :integer, :default => 1,  :null => false

  end

  def self.down
    change_column :groups_users, :group_id, :integer, :default => 0
    change_column :groups_users,  :user_id, :integer, :default => 0
    change_column :nodes,         :user_id, :integer, :default => 0
    change_column :links,       :source_id, :integer, :default => 0
    change_column :links,       :target_id, :integer, :default => 0
    change_column :versions,      :node_id, :integer, :default => 0
    change_column :versions,      :user_id, :integer, :default => 0

    change_column :versions,       :status, :integer, :default => 30, :null => true
    change_column :versions,       :number, :integer, :default => 1,  :null => true
  end
end