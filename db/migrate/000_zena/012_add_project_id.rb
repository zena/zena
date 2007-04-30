class AddProjectId < ActiveRecord::Migration
  def self.up
    add_column :nodes, :project_id, :integer
    execute "UPDATE nodes SET project_id = section_id"
  end

  def self.down
    remove_column :nodes, :project_id
  end
end
