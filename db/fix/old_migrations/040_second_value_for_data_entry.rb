class SecondValueForDataEntry < ActiveRecord::Migration
  def self.up
    rename_column :data_entries, :value, :value_a
    add_column    :data_entries, :value_b, :decimal, :precision => 24, :scale => 8
  end

  def self.down
    rename_column :data_entries, :value_a, :value
    remove_column :data_entries, :value_b
  end
end
