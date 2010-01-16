class AddPersistenceToken < ActiveRecord::Migration
  User.reset_column_information
  def self.up
    add_column :users, :persistence_token, :string
    unless User.column_names.include?('password_salt')
      # Strangely some legacy apps already have the password_salt. Better be safe.
      add_column :users, :password_salt, :string
    end
    rename_column :users, :password, :crypted_password
  end

  def self.down
    remove_column :users, :persistence_token
    remove_column :users, :password_salt
    rename_column :users, :crypted_password, :password
  end
end
