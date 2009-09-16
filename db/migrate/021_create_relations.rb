class CreateRelations < ActiveRecord::Migration
  def self.up
    create_table(:relations, :options => 'type=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci') do |t|
      t.column :source_role, :string,  :limit => 32
      t.column :source_kpath, :string, :limit => 16
      t.column :source_unique, :boolean
      t.column :source_icon, :string, :limit => 200

      t.column :target_role, :string,  :limit => 32
      t.column :target_kpath, :string, :limit => 16
      t.column :target_unique, :boolean
      t.column :target_icon, :string, :limit => 200

      t.column :site_id, :integer, :null => false
    end
    add_column :links, 'relation_id', :integer
  end

  def self.down
    drop_table :relations
    remove_column :links, 'relation_id'
  end
end
