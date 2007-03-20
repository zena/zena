class UserStatus < ActiveRecord::Migration
  def self.up
    add_column :users, :status, :integer
    User.connection.execute "UPDATE users SET status='60' WHERE 1"
  end

  def self.down
    remove_column :users, :status
  end
end
