class AddGroupToRelation < ActiveRecord::Migration
  def self.up
    add_column :relations, :rel_group, :string
  end

  def self.down
    remove_column :relations, :rel_group
  end
end
