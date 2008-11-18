class AddAutoCreateDiscussionToVClass < ActiveRecord::Migration
  def self.up
    add_column :virtual_classes, :auto_create_discussion, :boolean
    remove_column :virtual_classes, :allowed_attributes
  end

  def self.down
    remove_column :virtual_classes, :auto_create_discussion
    add_column :virtual_classes, :allowed_attributes, :text
  end
end
