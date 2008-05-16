class AddStatusToLink < ActiveRecord::Migration
  def self.up
    remove_column :links, :role
    add_column :links, :status, :integer
    add_column :links, :comment, :string, :limit => 60
  end

  def self.down
    add_column :links, :role, :string, :limit => 20
    remove_column :links, :status
    remove_column :links, :comment
  end
end