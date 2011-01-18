class AddDynamoToVersion < ActiveRecord::Migration
  def self.up
    add_column :versions, :dynamo, :text
  end

  def self.down
    remove_column :versions, :dynamo
  end
end
