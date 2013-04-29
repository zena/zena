class FixCreateKpathDefault < ActiveRecord::Migration
  def self.up
    execute %Q{UPDATE acls SET create_kpath = 'N' WHERE create_kpath IS NULL}
  end

  def self.down
  end
end
