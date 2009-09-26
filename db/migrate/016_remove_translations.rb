class RemoveTranslations < ActiveRecord::Migration
  def self.up
    drop_table 'trans_phrases'
    drop_table 'trans_values'
    remove_column 'sites', 'trans_group_id'
  end

  def self.down
    add_column 'sites', :trans_group_id, :integer
    create_table("trans_phrases", :options => Zena::Db.table_options) do |t|
      t.column "phrase", :string, :limit => 100, :default => "", :null => false
    end

    create_table("trans_values", :options => Zena::Db.table_options) do |t|
      t.column "phrase_id", :integer
      t.column "lang", :string, :limit => 10, :default => "", :null => false
      t.column "value", :text, :default => "", :null => false
    end
  end
end
