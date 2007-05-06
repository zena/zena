class AddProjectId < ActiveRecord::Migration
  def self.up
    add_column :nodes, :project_id, :integer
    execute "UPDATE nodes SET project_id = section_id"
    execute "UPDATE nodes SET section_id = 1"
  end

  def self.down
    execute "UPDATE nodes SET section_id = project_id"
    remove_column :nodes, :project_id
  end
end
