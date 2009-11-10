class AddPersistenceToken < ActiveRecord::Migration
  def self.up
    add_column :users, :persistence_token, :string
    add_column :users, :password_salt, :string
    rename_column :users, :password, :crypted_password
  end

  def self.down
    remove_column :users, :persistence_token
    remove_column :users, :password_salt
    rename_column :users, :crypted_password, :password
  end
end
