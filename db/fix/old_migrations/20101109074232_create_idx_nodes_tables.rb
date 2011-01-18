class CreateIdxNodesTables < ActiveRecord::Migration
  def self.up
    # index float for nodes
    create_table :idx_nodes_floats, :options => Zena::Db.table_options do |t|
      t.integer  'node_id', :null => false
      t.string   'key'
      t.float    'value'
    end
    add_index(:idx_nodes_floats, [:node_id, :key])
    add_index(:idx_nodes_floats, :value)
    add_index(:idx_nodes_floats, :node_id)

    # index datetime for nodes
    create_table :idx_nodes_datetimes, :options => Zena::Db.table_options do |t|
      t.integer  'node_id', :null => false
      t.string   'key'
      t.datetime 'value'
    end
    
    add_index :idx_nodes_datetimes, [:node_id, :key]
    add_index :idx_nodes_datetimes, :value
    add_index :idx_nodes_datetimes, :node_id
     
    add_column :nodes, :idx_datetime1, :datetime
    add_index  :nodes, :idx_datetime1
    
    add_column :nodes, :idx_datetime2, :datetime
    add_index  :nodes, :idx_datetime2
    
    add_column :nodes, :idx_float1, :float
    add_index  :nodes, :idx_float1
    
    add_column :nodes, :idx_float2, :float
    add_index  :nodes, :idx_float2
    
    add_column :nodes, :idx_string1, :string
    add_index  :nodes, :idx_string1
    
    add_column :nodes, :idx_string2, :string
    add_index  :nodes, :idx_string2
  end

  def self.down
    drop_table 'idx_nodes_floats'
    drop_table 'idx_nodes_datetimes'
    
    remove_column :nodes, :idx_datetime1
    remove_index  :nodes, :idx_datetime1
    
    remove_column :nodes, :idx_datetime2
    remove_index  :nodes, :idx_datetime2
    
    remove_column :nodes, :idx_float1
    remove_index  :nodes, :idx_float1
    
    remove_column :nodes, :idx_float2
    remove_index  :nodes, :idx_float2
    
    remove_column :nodes, :idx_string1
    remove_index  :nodes, :idx_string1
    
    remove_column :nodes, :idx_string2
    remove_index  :nodes, :idx_string2
  end
end
