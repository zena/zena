class CreateScopeIndex < ActiveRecord::Migration
  def self.up
    # Model to use as index
    add_column :roles, :idx_class, :string, :limit => 30
    
    # Related models whose scope indices need to be updated after
    # save
    add_column :roles, :idx_scope, :string

    create_table(:idx_projects, :options => Zena::Db.table_options) do |t|
      t.integer  :site_id
      t.integer  :node_id
      
      # Blog (self) (NPPB)
      t.integer  :NPP_id
      t.string   :NPP_title
      
      # Contact (project or references) (NRC)
      t.integer  :NRC_id
      t.string   :NRC_first_name
      t.string   :NRC_name
      
      # Tag (project) (NPT)
      t.integer  :NPT_id
      t.datetime :NPT_created_at
      t.string   :NPT_title
    end
  end

  def self.down
    remove_column :roles, :idx_class
    remove_column :roles, :idx_scope
    drop_table :idx_projects
  end
end
