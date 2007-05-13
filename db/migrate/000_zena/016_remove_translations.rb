class RemoveTranslations < ActiveRecord::Migration
  def self.up
    drop_table 'trans_phrases'
    drop_table 'trans_values'
  end

  def self.down
    create_table("trans_phrases", :options => 'type=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci') do |t|
      t.column "phrase", :string, :limit => 100, :default => "", :null => false
    end

    create_table("trans_values", :options => 'type=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci') do |t|
      t.column "phrase_id", :integer
      t.column "lang", :string, :limit => 10, :default => "", :null => false
      t.column "value", :text, :default => "", :null => false
    end
  end
end
