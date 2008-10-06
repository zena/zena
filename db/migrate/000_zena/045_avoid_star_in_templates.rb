class AvoidStarInTemplates < ActiveRecord::Migration
  def self.up
    execute "UPDATE #{TemplateContent.table_name} SET mode = REPLACE(mode, '*', '+')"
    execute "UPDATE #{Node.table_name} SET name = REPLACE(name, '*', '+')"
    execute "UPDATE #{Version.table_name} SET title = REPLACE(title, '*', '+')"
  end

  def self.down
    execute "UPDATE #{TemplateContent.table_name} SET mode = REPLACE(mode, '+', '*')"
    execute "UPDATE #{Node.table_name} SET name = REPLACE(name, '+', '*')"
    execute "UPDATE #{Version.table_name} SET title = REPLACE(title, '+', '*')"
  end
end
