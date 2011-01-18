class StorePropertiesInLongText < ActiveRecord::Migration
  def self.up
    Zena::Db.change_column :versions, :properties, :text
  end

  def self.down
    change_column :versions, :properties, :text
  end
end
