class CreateIdxNodesMlString < ActiveRecord::Migration
  def self.up
    # index strings for nodes
    create_table :idx_nodes_ml_strings, :options => Zena::Db.table_options, :id => false do |t|
      t.integer 'node_id', :null => false
      t.string  'key'
      t.string  'lang', :limit => 10
      t.string  'value'
    end
  end

  def self.down
    drop_table 'idx_nodes_ml_strings'
  end
end
