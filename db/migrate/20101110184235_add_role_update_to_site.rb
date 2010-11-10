class AddRoleUpdateToSite < ActiveRecord::Migration
  def self.up
    add_column :sites, :roles_updated_at, :datetime
  end

  def self.down
    remove_column :sites, :roles_updated_at
  end
end
