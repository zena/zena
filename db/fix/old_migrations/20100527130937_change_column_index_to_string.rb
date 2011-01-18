class ChangeColumnIndexToString < ActiveRecord::Migration
  def self.up
    change_column :columns, :index, :string, :limit => 30
  end

  def self.down
    change_column :columns, :index, :boolean
  end
end
