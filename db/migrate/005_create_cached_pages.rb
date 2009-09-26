class CreateCachedPages < ActiveRecord::Migration
  def self.up
    create_table(:cached_pages, :options => Zena::Db.table_options) do |t|
      t.column :path, :text
      t.column :expire_after, :datetime
      t.column :created_at, :datetime
      t.column :node_id, :integer
    end

    create_table(:cached_pages_nodes, :id=>false, :options => Zena::Db.table_options) do |t|
      t.column :cached_page_id, :integer
      t.column :node_id, :integer
    end
  end

  def self.down
    drop_table :cached_pages
    drop_table :cached_pages_nodes
  end
end
