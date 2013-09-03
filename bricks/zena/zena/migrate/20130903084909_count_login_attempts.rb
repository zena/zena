class CountLoginAttempts < ActiveRecord::Migration
  def self.up
    add_column :users, :login_attempt_count, :integer
    add_column :users, :login_attempted_at, :datetime
  end

  def self.down
    remove_column :users, :login_attempt_count
    remove_column :users, :login_attempted_at
  end
end
