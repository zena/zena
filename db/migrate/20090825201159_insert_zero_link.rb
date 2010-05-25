class InsertZeroLink < ActiveRecord::Migration
  def self.up
    Zena::Db.insert_zero_link(Link)
  end

  def self.down
  end
end
