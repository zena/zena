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
    
    add_column :cached_pages, :site_id, :integer
    # relation, no site_id: :cached_pages_nodes
    add_column :caches, :site_id, :integer
    add_column :comments, :site_id, :integer
    add_column :contact_contents, :site_id, :integer
    add_column :discussions, :site_id, :integer
    add_column :document_contents, :site_id, :integer
    add_column :groups, :site_id, :integer
    # relation, no site_id: :groups_users
    # relation, no site_id: :links
    add_column :nodes,:site_id, :integer
    add_column :trans_phrases, :site_id, :integer
    # relation, no site_id: :trans_values
    # users : cross site
    add_column :versions, :site_id, :integer
  end
  
  def self.down
    drop_table :sites
    drop_table :sites_users
    
    remove_column :cached_pages, :site_id
    remove_column :caches, :site_id
    remove_column :comments, :site_id
    remove_column :contact_contents, :site_id
    remove_column :discussions, :site_id
    remove_column :document_contents, :site_id
    remove_column :groups, :site_id
    remove_column :nodes,:site_id
    remove_column :trans_phrases, :site_id
    remove_column :versions, :site_id
  end
end