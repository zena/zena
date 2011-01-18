class TransformTemplateContentsIntoIndex < ActiveRecord::Migration
  def self.up
    remove_column :template_contents, :klass
    rename_table  :template_contents, :idx_templates
    add_column    :idx_templates, :version_id, :integer
  end

  def self.down
    remove_column :idx_templates, :version_id
    add_column    :idx_templates, :klass, :string
    rename_table :idx_templates, :template_contents
  end
end
