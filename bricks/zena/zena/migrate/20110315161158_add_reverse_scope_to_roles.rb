class AddReverseScopeToRoles < ActiveRecord::Migration
  def self.up
    add_column :roles, :idx_reverse_scope, :string
  end

  def self.down
    remove_column :roles, :idx_reverse_scope
  end
end
