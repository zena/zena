class AddProfileToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :is_profile, :boolean
    add_column :users, :profile_id, :integer
  end

  def self.down
    remove_column :users, :profile_id
    remove_column :users, :is_profile
  end
end
