class CreateScopeIndex < ActiveRecord::Migration
  def self.up
    add_column :roles, :scope_index, :string, :limit => 30

    create_table(:idx_projects, :options => Zena::Db.table_options) do |t|
      t.integer  :site_id
      t.integer  :node_id

      t.integer  :NP_id
      t.string   :NP_created_at

      t.integer  :NN_id
      t.datetime :NN_log_at

      t.integer  :NNP_id
      t.string   :NNP_origin
      t.string   :NNP_title

      t.integer  :NPP_id
      t.string   :NPP_title
    end
  end

  def self.down
    remove_column :roles, :scope_index
    drop_table :idx_projects
  end
end
