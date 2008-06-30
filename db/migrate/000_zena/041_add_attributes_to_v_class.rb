class AddAttributesToVClass < ActiveRecord::Migration
  def self.up
    add_column    :virtual_classes, :dyn_keys, :text
  end

  def self.down
    remove_column :virtual_classes, :dyn_keys
  end
end
