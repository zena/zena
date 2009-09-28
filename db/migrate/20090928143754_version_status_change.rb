class VersionStatusChange < ActiveRecord::Migration
  STATUS_CHANGES = {
    30 => 70,
    35 => 65,
    40 => 60,
  }
  def self.up
    change_column :versions, :status, :integer, :default => 70, :null => false
    remove_column :nodes, :max_status

    STATUS_CHANGES.each do |from, to|
      execute "UPDATE versions SET status = #{to} WHERE status = #{from}"
    end
  end

  def self.down
    change_column :versions, :status, :integer, :default => 30, :null => false
    create_column :nodes, :max_status, :integer, :default => 30

    STATUS_CHANGES.each do |from, to|
      execute "UPDATE versions SET status = #{from} WHERE status = #{to}"
    end
  end
end
