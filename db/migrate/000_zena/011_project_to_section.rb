class ProjectToSection < ActiveRecord::Migration
  def self.up
    rename_column :nodes, "project_id", "section_id"
  end

  def self.down
    rename_column :nodes, "section_id", "project_id"
  end
end
