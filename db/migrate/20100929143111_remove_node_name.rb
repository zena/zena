class RemoveNodeName < ActiveRecord::Migration
  def self.up
    remove_column :nodes, :node_name
    add_column :nodes, :_id, :string, :limit => 40
  end

  def self.down
    remove_column :nodes, :_id
    add_column :nodes, :node_name, :text
  end
end
