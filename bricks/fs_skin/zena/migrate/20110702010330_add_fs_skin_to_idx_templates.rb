class AddFsSkinToIdxTemplates < ActiveRecord::Migration
  def self.up
    add_column :idx_templates, :fs_skin, :string, :limit => 30
    add_column :idx_templates, :path, :string, :limit => 300
    add_index  :idx_templates, [:fs_skin], :name => "index_idx_templates_on_fs_skin"
  end

  def self.down
    remove_index  :idx_templates, :name => "index_idx_templates_on_fs_skin"
    remove_column :idx_templates, :fs_skin
  end
end
