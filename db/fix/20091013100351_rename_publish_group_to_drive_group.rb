class RenamePublishGroupToDriveGroup < ActiveRecord::Migration
  def self.up
    remove_column :nodes, :dgroup_id  # old stuff
    rename_column :nodes, :pgroup_id, :dgroup_id
  end

  def self.down
    rename_column :nodes, :dgroup_id, :pgroup_id
  end
end
