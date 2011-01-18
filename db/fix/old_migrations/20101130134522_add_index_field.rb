class AddIndexField < ActiveRecord::Migration
  def self.up
    add_column :nodes, :idx_integer1, :integer
    add_index  :nodes, :idx_integer1
    add_column :nodes, :idx_integer2, :integer
    add_index  :nodes, :idx_integer2
  end

  def self.down
    remove_column :nodes, :idx_integer1
    remove_column :nodes, :idx_integer2
  end
end
