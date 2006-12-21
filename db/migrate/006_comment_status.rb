class CommentStatus < ActiveRecord::Migration
  def self.up
    add_column :comments, 'status', :integer
  end

  def self.down
    remove_column :comments, 'status'
  end
end
