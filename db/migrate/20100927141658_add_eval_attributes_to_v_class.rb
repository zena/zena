class AddEvalAttributesToVClass < ActiveRecord::Migration
  def self.up
    add_column :roles, :properties, :text
    remove_column :roles, :dyn_keys
    remove_column :roles, :idx_text_high
    remove_column :roles, :idx_text_medium
    remove_column :roles, :idx_text_low
  end

  def self.down
  end
end
