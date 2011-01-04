class RenamePublishGroupToDriveGroup < ActiveRecord::Migration
  def self.up
    unless $migrating_new_db
      remove_column :nodes, :dgroup_id  # old stuff
    end
    rename_column :nodes, :pgroup_id, :dgroup_id
  end

  def self.down
    rename_column :nodes, :dgroup_id, :pgroup_id
  end
end
