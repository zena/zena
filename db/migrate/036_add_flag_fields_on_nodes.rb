class AddFlagFieldsOnNodes < ActiveRecord::Migration
  def self.up
    add_column :nodes, :custom_a, :integer
    add_column :nodes, :custom_b, :integer
  end

  def self.down
    remove_column :nodes, :custom_a
    remove_column :nodes, :custom_b
  end
end
