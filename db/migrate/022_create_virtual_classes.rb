class CreateVirtualClasses < ActiveRecord::Migration
  def self.up
    create_table(:virtual_classes, :options => 'type=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci') do |t|
      t.column :name, :string
      t.column :kpath, :string, :limit => 16
      t.column :real_class, :string, :limit => 16
      t.column :icon, :string, :limit => 200
      t.column :allowed_attributes, :text
      t.column :create_group_id, :integer # who is allowed to create objects of this type

      t.column :site_id, :integer, :null => false
    end
    add_column :nodes, :vclass_id, :integer
  end

  def self.down
    drop_table :virtual_classes
    remove_column :nodes, :vclass_id
  end
end
