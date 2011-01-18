class RemoveSuUser < ActiveRecord::Migration
  def self.up
    remove_column :sites, :su_id
  end

  def self.down
  end
end
