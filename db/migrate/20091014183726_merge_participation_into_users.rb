class MergeParticipationIntoUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :site_id, :integer
    Zena::Db.update_value('users.site_id', :from => 'participations.site_id',
                          :where => "users.id=participations.user_id")

    add_column :users, :status, :integer
    Zena::Db.update_value('users.status', :from => 'participations.status',
                          :where => "users.id=participations.user_id")

    add_column :users, :contact_id, :integer
    Zena::Db.update_value('users.contact_id', :from => 'participations.contact_id',
                          :where => "users.id=participations.user_id")

    add_column    :users, :lang, :string, :limit => 10, :default => "", :null => false
    Zena::Db.update_value('users.lang', :from => 'participations.lang',
                          :where => 'users.id = participations.user_id')

    drop_table :participations
  end
end
