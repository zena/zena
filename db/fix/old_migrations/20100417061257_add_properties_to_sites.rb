class AddPropertiesToSites < ActiveRecord::Migration
  def self.up
    add_column :sites, :properties, :text
  end

  def self.down
    remove_column :sites, :properties
  end
end
