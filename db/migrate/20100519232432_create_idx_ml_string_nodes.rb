class CreateIdxMlStringNodes < ActiveRecord::Migration
  def self.up
    # index strings for nodes
    create_table 'idx_ml_string_nodes' do |t|
      t.integer 'node_id'
      t.string  'key'
      t.string  'lang', :limit => 10
      t.string  'value'
    end
  end

  def self.down
    drop_table 'idx_ml_string_nodes'
  end
end
