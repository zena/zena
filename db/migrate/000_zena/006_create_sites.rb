class CreateSites < ActiveRecord::Migration
  def self.up
    create_table(:sites, :options => 'type=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci') do |t|
      t.column :host, :string
      t.column :root_id, :integer
      t.column :su_id, :integer
      t.column :anon_id, :integer
      t.column :public_group_id, :integer
      t.column :admin_group_id, :integer
      t.column :site_group_id, :integer
      t.column :trans_group_id, :integer
      t.column :name, :string
      t.column :authorize, :boolean
      t.column :monolingual, :boolean
      t.column :allow_private, :boolean
      t.column :languages, :string, :size=>400
      t.column :default_lang, :string, :size=>2
    end
    
    create_table(:sites_users, :id=>false,:options => 'type=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci') do |t|
      t.column :user_id, :integer
      t.column :site_id, :integer
      t.column :status, :integer
    end
    
    add_column :groups, :site_id, :integer
    add_column :nodes,  :site_id, :integer
  end

  def self.down
    drop_table :sites
    drop_table :sites_users
    remove_column :groups, :site_id
    remove_column :nodes, :site_id
  end
end
