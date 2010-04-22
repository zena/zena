class NodeHabtmRoles < ActiveRecord::Migration
  def self.up

    create_table('nodes_roles', :options => Zena::Db.table_options) do |t|
      t.integer 'node_id', :integer, :default => 0, :null => false
      t.integer 'role_id', :integer, :default => 0, :null => false
      t.column 'role', :string, :limit => 20
    end
  end

  def self.down
    drop_table('nodes_roles')
  end
end
