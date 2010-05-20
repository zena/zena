class AddLangToIStringNodes < ActiveRecord::Migration
  def self.up
    add_column :i_string_nodes, :lang, :string, :limit => 10
  end

  def self.down
    remove_column :i_string_nodes, :lang
  end
end
