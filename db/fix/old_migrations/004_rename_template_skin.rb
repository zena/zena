class RenameTemplateSkin < ActiveRecord::Migration
  def self.up
    rename_column 'nodes', 'template', 'skin'
  end

  def self.down
    rename_column 'nodes', 'skin', 'template'
  end
end
