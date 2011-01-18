class NodeHabtmRoles < ActiveRecord::Migration
  def self.up

    create_table('nodes_roles', :options => Zena::Db.table_options, :id => false) do |t|
      t.integer 'node_id', :default => 0, :null => false
      t.integer 'role_id', :default => 0, :null => false
    end
  end

  def self.down
    drop_table('nodes_roles')
  end
end
