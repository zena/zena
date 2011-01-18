class ChangeScopeIndex < ActiveRecord::Migration
  def self.up
    drop_table :idx_projects
    create_table(:idx_projects, :options => Zena::Db.table_options) do |t|
      t.integer  :site_id
      t.integer  :node_id

      # Blog (self) (NPPB)
      t.integer  :blog_id
      t.string   :blog_title

      # Contact in project
      t.integer  :contact_id
      t.string   :contact_first_name
      t.string   :contact_name

      # Contact as reference
      t.integer  :reference_id
      t.string   :reference_name
      t.string   :reference_title

      # Tag in project
      t.integer  :tag_id
      t.datetime :tag_created_at
      t.string   :tag_title
    end
  end

  def self.down
  end
end
