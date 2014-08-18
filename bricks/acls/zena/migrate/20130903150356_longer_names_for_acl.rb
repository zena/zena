class LongerNamesForAcl < ActiveRecord::Migration
  def self.up
    change_column :acls, :name, :string, :limit => 60
  end

  def self.down
    change_column :acls, :name, :string, :limit => 30
  end
end
