class CreateSites < ActiveRecord::Migration
  def self.up
    create_table(:sites, :options => 'type=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci') do |t|
      t.column :host, :string
      t.column :root_id, :integer
      t.column :su_id, :integer
      t.column :anon_id, :integer
      t.column :trans_group_id, :integer
      t.column :authenticated_prefix, :string, :size=>2
      t.column :name, :string
      t.column :authorize, :boolean
      t.column :monolingual, :boolean
      t.column :allow_private, :boolean
      t.column :password_salt, :string
      t.column :languages, :string, :size=>400
      t.column :default_lang, :string, :size=>2
    end
    create_table(:users_sites, :id=>false,:options => 'type=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci') do |t|
      t.column :user_id, :integer
      t.column :group_id, :integer
      t.column :status, :integer
    end
    add_column :groups, :site_id, :integer
    add_column :nodes,  :site_id, :integer
  end

  def self.down
    drop_table :sites
    drop_table :users_site
    remove_column :groups, :site_id
    remove_column :nodes, :site_id
  end
end
