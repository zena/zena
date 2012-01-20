class AddCommentToRelations < ActiveRecord::Migration
  def self.up
    add_column :relations, :comment, :text
  end

  def self.down
    remove_column :relations, :comment
  end
end
