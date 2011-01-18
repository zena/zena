class MoveUserLangIntoParticipation < ActiveRecord::Migration
  def self.up
    add_column    :participations, :lang, :string, :limit => 10, :default => "", :null => false
    Zena::Db.update_value('participations.lang', :from => 'users.lang',
                          :where => 'participations.user_id = users.id')
    remove_column :users, :lang
  end

  def self.down
    add_column    :users, :lang, :string, :limit => 10, :default => "", :null => false
    Zena::Db.update_value('users.lang', :from => 'participations.lang',
                          :where => 'participations.user_id = users.id')
    remove_column :participations, :lang
  end
end
