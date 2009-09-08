class InsertZeroLink < ActiveRecord::Migration
  def self.up
    NodeQuery.insert_zero_link(Link)
  end

  def self.down
  end
end
