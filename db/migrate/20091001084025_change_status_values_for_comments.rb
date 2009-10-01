class ChangeStatusValuesForComments < ActiveRecord::Migration
  STATUS_CHANGES = {
    30 => 70,
    35 => 65,
    40 => 60,
  }
  def self.up
    change_column :comments, :status, :integer, :default => 70, :null => false

    STATUS_CHANGES.each do |from, to|
      execute "UPDATE comments SET status = #{to} WHERE status = #{from}"
    end
  end

  def self.down
    change_column :versions, :status, :integer

    STATUS_CHANGES.each do |from, to|
      execute "UPDATE comments SET status = #{from} WHERE status = #{to}"
    end
  end
end
