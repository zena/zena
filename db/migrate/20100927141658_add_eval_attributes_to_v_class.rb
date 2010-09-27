class AddEvalAttributesToVClass < ActiveRecord::Migration
  def self.up
    add_column :roles, :prop_eval, :text
    remove_column :roles, :dyn_keys
  end

  def self.down
  end
end
