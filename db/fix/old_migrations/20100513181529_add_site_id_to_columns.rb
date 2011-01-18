class AddSiteIdToColumns < ActiveRecord::Migration
  def self.up
    add_column :columns, :site_id, :integer
  end

  def self.down
    remove_column :columns, :site_id
  end
end
