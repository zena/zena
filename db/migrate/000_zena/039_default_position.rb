class DefaultPosition < ActiveRecord::Migration
  def self.up
    change_column :nodes, :position, :integer, :default => 0.0
    execute "UPDATE nodes SET position = 0.0 where position = 1.0;"
  end

  def self.down
    change_column :nodes, :position, :integer, :default => 1.0
  end
end