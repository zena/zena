class AddCommentToColumns < ActiveRecord::Migration
  def self.up
    add_column :columns, :comment, :text
  end

  def self.down
    remove_column :columns, :comment
  end
end
