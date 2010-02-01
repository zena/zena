class RemoveDefaultStatusOnVersion < ActiveRecord::Migration
  def self.up
    change_column :versions, :status, :integer, :default => nil
  end

  def self.down
    change_column :versions, :status, :integer, :default => 70
  end
end
