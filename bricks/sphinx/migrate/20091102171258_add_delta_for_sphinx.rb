class AddDeltaForSphinx < ActiveRecord::Migration
  def self.up
    add_column :nodes, :delta, :boolean, :default => true, :null => false
  end

  def self.down
    remove_column :nodes, :delta
  end
end
