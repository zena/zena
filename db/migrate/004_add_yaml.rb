class AddYaml < ActiveRecord::Migration
  def self.up
    add_column 'versions', :yaml, :text
  end

  def self.down
    remove_column 'versions', :yaml
  end
end
