class LinkSourceTargetCanBeNull < ActiveRecord::Migration
  def self.up
    change_column :links, :target_id, :integer, :null => true
    change_column :links, :source_id, :integer, :null => true
  end

  def self.down
    change_column :links, :target_id, :integer, :null => false
    change_column :links, :source_id, :integer, :null => false
  end
end
