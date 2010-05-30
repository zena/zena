class InsertZeroLink < ActiveRecord::Migration
  def self.up
    Zena::Db.insert_dummy_ids
  end

  def self.down
  end
end
