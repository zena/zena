class CreateTemplateContent < ActiveRecord::Migration
  def self.up
      create_table(:template_contents, :options => Zena::Db.table_options) do |t|
        t.column :site_id, :integer
        t.column :node_id, :integer
        t.column :skin_name, :string
        t.column :format, :string
        t.column :tkpath, :string
        t.column :klass, :string
        t.column :mode, :string
      end
  end

  def self.down
    drop_table :template_contents
  end
end
