class RenamedContactModelToBaseContact < ActiveRecord::Migration
  def self.up
    execute "UPDATE nodes SET type = 'BaseContact' WHERE type = 'Contact'"
    execute "UPDATE roles SET real_class = 'BaseContact' WHERE real_class = 'Contact'"
  end

  def self.down
    execute "UPDATE nodes SET type = 'Contact' WHERE type = 'BaseContact'"
    execute "UPDATE roles SET real_class = 'Contact' WHERE real_class = 'BaseContact'"
  end
end
