class IpOnAnonymousComment < ActiveRecord::Migration
  def self.up
    add_column :comments, :ip, :string, :limit=>200
  end

  def self.down
    remove_column :comments, :ip
  end
end
