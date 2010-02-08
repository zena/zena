class InsertZeroLink < ActiveRecord::Migration
  def self.up
    Zena::Use::QueryNode.insert_zero_link(Link)
  end

  def self.down
  end
end
