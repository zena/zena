class CreateAcls < ActiveRecord::Migration
  def self.up
    create_table :acls do |t|
      t.string :name, :limit => 30
      t.string :description
      t.string :query
      t.string :action
      t.integer :site_id
      t.integer :group_id
      t.integer :exec_group_id
      t.integer :exec_skin_id
      t.integer :priority

      t.timestamps
    end
    add_column :users, :use_acls, :boolean
  end

  def self.down
    drop_table :acls
  end
end
