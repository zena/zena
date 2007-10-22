class AddCountryToContacts < ActiveRecord::Migration
  def self.up
    add_column :contact_contents, "country", :string, :limit => 100
  end

  def self.down
    remove_column :contact_contents, "country"
  end
end
