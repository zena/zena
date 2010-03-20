class TransformTemplateContentsIntoIndex < ActiveRecord::Migration
  def self.up
    remove_column :template_contents, :klass
    rename_table  :template_contents, :template_indices
    add_column    :template_indices, :version_id, :integer
  end

  def self.down
    remove_column :template_indices, :version_id
    add_column    :template_indices, :klass, :string
    rename_table :template_indices, :template_contents
  end
end
