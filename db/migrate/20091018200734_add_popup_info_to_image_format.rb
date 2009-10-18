class AddPopupInfoToImageFormat < ActiveRecord::Migration
  def self.up
    add_column :iformats, :popup, :string, :limit => 120
  end

  def self.down
    remove_column :iformats, :popup
  end
end
