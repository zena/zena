class AddAuthOption < ActiveRecord::Migration
  def self.up
    add_column :sites, "http_auth", :boolean, :default => nil
  end

  def self.down
    remove_column :sites, "http_auth"
  end
end
