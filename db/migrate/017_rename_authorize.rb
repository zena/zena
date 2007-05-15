class RenameAuthorize < ActiveRecord::Migration
  def self.up
    rename_column :sites, "authorize", "authentication"
  end

  def self.down
    rename_column :sites, "authentication", "authorize"
  end
end
