class AddIndexDefinitionToColumns < ActiveRecord::Migration
  def self.up
    add_column :columns, :index, :integer
  end

  def self.down
    remove_column :columns, :index
  end
end
