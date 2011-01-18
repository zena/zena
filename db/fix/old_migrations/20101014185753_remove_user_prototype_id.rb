class RemoveUserPrototypeId < ActiveRecord::Migration
  def self.up
    remove_column :sites, :usr_prototype_id
  end

  def self.down
    add_column :sites, :usr_prototype_id, :integer
  end
end
