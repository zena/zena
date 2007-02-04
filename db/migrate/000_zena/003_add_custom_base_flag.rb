class AddCustomBaseFlag < ActiveRecord::Migration
  def self.up
    add_column 'nodes', 'custom_base', :boolean, :default=>false
  end

  def self.down
    remove_column 'nodes', 'custom_base'
  end
end
