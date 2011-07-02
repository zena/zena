class AddStaticToIdxTemplates < ActiveRecord::Migration
  def self.up
    add_column :idx_templates, :static, :string, :limit => 30
    add_column :idx_templates, :path, :string, :limit => 300
    add_index  :idx_templates, [:static], :name => "index_idx_templates_on_static"
  end

  def self.down
    remove_index  :idx_templates, :name => "index_idx_templates_on_static"
    remove_column :idx_templates, :static
  end
end
