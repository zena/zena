class CreateDataEntries < ActiveRecord::Migration
  def self.up
    create_table :data_entries do |t|
      t.column :site_id, :integer        # auth
      t.column :created_at, :datetime  #
      t.column :updated_at, :datetime  # signature
      t.column :user_id, :integer      #
      t.column :date, :datetime                                 #
      t.column :text, :text                                     # value
      t.column :value, :decimal, :precision => 24, :scale => 8  #
      t.column :node_a_id, :integer     #
      t.column :node_b_id, :integer     # links
      t.column :node_c_id, :integer     #
      t.column :node_d_id, :integer     #
    end
  end

  def self.down
    drop_table :data_entries
  end
end
