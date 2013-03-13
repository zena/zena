class AddCreateKpathToAcl < ActiveRecord::Migration
  def self.up
    add_column :acls, :create_kpath, :string, :limit => 200
    add_index :acls, ["create_kpath", "group_id", "action", "site_id"]
  end

  def self.down
    remove_column :groups, :auto_publish
    remove_index :acls, :column => ["create_kpath", "group_id", "action", "site_id"]
  end
end
