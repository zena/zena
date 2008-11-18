class Fulltext < ActiveRecord::Migration
  def self.up
    # convert table from InnoDB to MyISAM
    execute "ALTER TABLE versions ENGINE = MyISAM;"
    # add fulltext index
    add_index "versions", ["title", "text", "summary"], :index_type => "FULLTEXT"
  end

  def self.down
    remove_index "versions", ["title", "text", "summary"]
    
    execute "ALTER TABLE versions ENGINE = InnoDB;"
  end
end
