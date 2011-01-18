class Fulltext < ActiveRecord::Migration
  def self.up
    Zena::Db.change_engine('versions', 'MyISAM')
    # add fulltext index
    add_index "versions", ["title", "text", "summary"], :index_type => "FULLTEXT"
  end

  def self.down
    remove_index "versions", ["title", "text", "summary"]

    Zena::Db.change_engine('versions', 'InnoDB')
  end
end
