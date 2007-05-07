class AddSortField < ActiveRecord::Migration
  def self.up
    add_column :nodes, :position, :float, :default => 1.0
    execute "UPDATE nodes SET position = 1.0;"
  end

  def self.down
    remove_column :nodes, :position
  end
end