class ChangeLinkStatusToFloat < ActiveRecord::Migration
  def self.up
    remove_index :links, :name => "index_links_on_status"
    change_column :links, :status, :float, :default => nil
    add_index :links, ["status"], :name => "index_links_on_status"
  end

  def self.down
    remove_index :links, :name => "index_links_on_status"
    change_column :links, :status, :integer, :default => nil
    add_index :links, ["status"], :name => "index_links_on_status"
  end
end
