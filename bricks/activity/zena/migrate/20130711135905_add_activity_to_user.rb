class AddActivityToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :seen_at, :datetime
  end

  def self.down
    remove_column :users, :seen_at
  end
end
