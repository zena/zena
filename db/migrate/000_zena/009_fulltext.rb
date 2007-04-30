class Fulltext < ActiveRecord::Migration
  def self.up
    # convert table from InnoDB to MyISAM
    if RAILS_ENV == 'production'
      execute "ALTER TABLE versions ENGINE = MyISAM;"
      # add fulltext index
      add_index "versions", ["title", "text", "summary"], :index_type => "FULLTEXT"
    end
  end

  def self.down
    if RAILS_ENV == 'production'
      remove_index "versions", ["title", "text", "summary"]
      
      execute "ALTER TABLE versions ENGINE = InnoDB;"
    end
  end
end
