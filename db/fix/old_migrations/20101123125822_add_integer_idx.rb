class AddIntegerIdx < ActiveRecord::Migration
  def self.up
    # index float for nodes
    create_table :idx_nodes_integers, :options => Zena::Db.table_options do |t|
      t.integer  'node_id', :null => false
      t.string   'key'
      t.integer  'value'
    end
    add_index(:idx_nodes_integers, [:node_id, :key])
    add_index(:idx_nodes_integers, :value)
    add_index(:idx_nodes_integers, :node_id)
  end

  def self.down
    drop_table 'idx_nodes_integers'
  end
end
