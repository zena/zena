class AddSiteReadonly < ActiveRecord::Migration
  def self.up
    add_column :sites, :site_readonly, :boolean
  end

  def self.down
    remove_column :sites, :site_readonly
  end
end
