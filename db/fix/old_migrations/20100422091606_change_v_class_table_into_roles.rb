class ChangeVClassTableIntoRoles < ActiveRecord::Migration
  def self.up
    add_column(:virtual_classes, :type, :string, :limit => 32)
    add_column(:virtual_classes, :created_at, :datetime)
    add_column(:virtual_classes, :updated_at, :datetime)

    rename_table(:virtual_classes, :roles)

    create_table(:stored_columns, :options => Zena::Db.table_options) do |t|
      t.integer 'stored_role_id'
      t.string 'name'
      # Property Type
      t.string 'ptype'
    end
    execute "UPDATE roles SET type = 'VirtualClass'"
    execute "UPDATE roles SET created_at = #{Zena::Db::NOW}"
    execute "UPDATE roles SET updated_at = #{Zena::Db::NOW}"
  end

  def self.down
    remove_column(:roles, :updated_at)
    remove_column(:roles, :created_at)
    remove_column(:roles, :type)
    rename_table(:roles, :virtual_classes)
    drop_table(:stored_columns)
  end
end
