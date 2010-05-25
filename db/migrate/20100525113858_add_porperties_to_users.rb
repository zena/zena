class AddPorpertiesToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :properties, :text
  end

  def self.down
    remove_column :users, :properties
  end
end
