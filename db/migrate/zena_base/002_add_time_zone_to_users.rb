class AddTimeZoneToUsers < ActiveRecord::Migration
  def self.up
    add_column 'users', 'timezone', :string
  end

  def self.down
    remove_column 'users', 'timezone'
  end
end
