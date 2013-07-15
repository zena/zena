class AlterLoginUsers < ActiveRecord::Migration
  def self.up
    change_column :users, :login, :string, :limit => 255
  end

  def self.down
    change_column :users, :login, :string, :limit => 20
  end
end
