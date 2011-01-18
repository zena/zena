# FIXME: move this with 'node_query' into a plugins might be cleaner
# make sure there exists a link with NULL content and id == -1 (used in queries using query order sorting)
class ChangeDefaultLinkIdToZero < ActiveRecord::Migration
  def self.up
    Link.connection.execute "UPDATE #{Link.table_name} SET id = 0 WHERE id = -1"
    Zena::Db.insert_dummy_ids
  end

  def self.down
    Link.connection.execute "UPDATE #{Link.table_name} SET id = -1 WHERE id = 0"
  end
end
