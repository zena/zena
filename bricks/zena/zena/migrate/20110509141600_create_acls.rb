class CreateAcls < ActiveRecord::Migration
  def self.up
    create_table :acls do |t|
      t.string :query
      t.string :action
      t.integer :site_id
      t.integer :group_id
      t.integer :exec_group_id
      t.integer :exec_skin_id
      t.integer :priority

      t.timestamps
    end
  end

  def self.down
    drop_table :acls
  end
end
