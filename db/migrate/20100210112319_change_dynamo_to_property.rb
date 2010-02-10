class ChangeDynamoToProperty < ActiveRecord::Migration
  def self.up
    rename_column :versions, :dynamo, :properties
  end

  def self.down
    rename_column :versions, :properties, :dynamo
  end
end
