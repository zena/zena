class RemoveUserStatus < ActiveRecord::Migration
  def self.up
    User.connection.execute "UPDATE sites_users,users SET sites_users.status=users.status WHERE users.id=sites_users.user_id;"
    remove_column :users, 'status'

    add_column :sites_users, 'contact_id', :integer # contact page for the given site
    User.connection.execute "UPDATE sites_users,users SET sites_users.contact_id=users.contact_id WHERE users.id=sites_users.user_id;"
    remove_column :users, 'contact_id'

    remove_column :sites, 'admin_group_id'
  end

  def self.down
    add_column :users, :status, :integer
    User.connection.execute "UPDATE users,sites_users SET users.status=sites_users.status WHERE user.id=sites_users.user_id;"

    add_column :users, 'contact_id', :integer # contact page for the given site
    User.connection.execute "UPDATE sites_users,users SET users.contact_id=sites_users.contact_id WHERE users.id=sites_users.user_id;"
    remove_column :sites_users, 'contact_id'
  end
end
