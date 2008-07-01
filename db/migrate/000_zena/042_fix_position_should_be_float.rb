class FixPositionShouldBeFloat < ActiveRecord::Migration
  def self.up
    change_column :nodes, :position, :float, :default => 1.0
  end

  def self.down
  end
end
