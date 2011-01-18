class RemoveUserStatus < ActiveRecord::Migration
  def self.up
    Zena::Db.update_value('sites_users.status', :from => 'users.status',
                          :where => 'users.id=sites_users.user_id')
    remove_column :users, 'status'

    add_column :sites_users, 'contact_id', :integer # contact page for the given site
    Zena::Db.update_value('sites_users.contact_id', :from => 'users.contact_id',
                          :where => 'users.id=sites_users.user_id')
    remove_column :users, 'contact_id'
    remove_column :sites, 'admin_group_id'
  end

  def self.down
    add_column :users, :status, :integer
    Zena::Db.update_value('users.status', :from => 'sites_users.status',
                          :where => "user.id=sites_users.user_id")

    add_column :users, 'contact_id', :integer # contact page for the given site

    Zena::Db.update_value('users.contact_id', :from => 'sites_users.contact_id',
                          :where => "user.id=sites_users.user_id")
    remove_column :sites_users, 'contact_id'
  end
end
