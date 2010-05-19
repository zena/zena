class CreateIStringNodes < ActiveRecord::Migration
  def self.up
    # index strings for nodes
    create_table 'i_string_nodes' do |t|
      t.integer 'node_id'
      t.string  'key'
      t.string  'value'
    end
  end

  def self.down
    drop_table 'i_string_nodes'
  end
end
