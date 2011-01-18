class RenameNameToNodeName < ActiveRecord::Migration
  def self.up
    rename_column :nodes, :name, :node_name
  end

  def self.down
    rename_column :nodes, :node_name, :name
  end
end
