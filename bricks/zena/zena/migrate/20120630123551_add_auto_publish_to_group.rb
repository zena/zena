class AddAutoPublishToGroup < ActiveRecord::Migration
  def self.up
    add_column :groups, :auto_publish, :boolean
  end

  def self.down
    remove_column :groups, :auto_publish
  end
end
