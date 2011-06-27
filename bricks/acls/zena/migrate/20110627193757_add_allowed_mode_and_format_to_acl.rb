class AddAllowedModeAndFormatToAcl < ActiveRecord::Migration
  def self.up
    add_column :acls, :mode,   :string, :limit => 20
    add_column :acls, :format, :string, :limit => 20
  end

  def self.down
    remove_column :acls, :mode
    remove_column :acls, :format
  end
end
