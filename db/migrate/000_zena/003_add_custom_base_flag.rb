class AddCustomBaseFlag < ActiveRecord::Migration
  def self.up
    add_column 'nodes', 'custom_base', :boolean, :default=>false
    add_column 'nodes', 'basepath', :text
  end

  def self.down
    remove_column 'nodes', 'custom_base'
    remove_column 'nodes', 'basepath'
  end
end
