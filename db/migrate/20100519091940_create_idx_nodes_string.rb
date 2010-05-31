class CreateIdxNodesString < ActiveRecord::Migration
  def self.up
    # index strings for nodes
    create_table :idx_nodes_string, :options => Zena::Db.table_options, :id => false do |t|
      t.integer 'node_id'
      t.string  'key'
      t.string  'value'
    end
  end

  def self.down
    drop_table 'idx_nodes_string'
  end
end
