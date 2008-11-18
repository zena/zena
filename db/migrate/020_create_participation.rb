class CreateParticipation < ActiveRecord::Migration
  def self.up
    create_table(:participations, :options => 'type=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci') do |t|
      t.column :user_id, :integer
      t.column :site_id, :integer
      t.column :status, :integer
      t.column :contact_id, :integer
    end
    values = select_all("SELECT * FROM sites_users").map do |r|
      "(#{['user_id','site_id','status','contact_id'].map {|k| quote(r[k])}.join(', ')})"
    end
    execute "INSERT INTO participations (`user_id`,`site_id`,`status`,`contact_id`) VALUES #{values.join(', ')}" unless values == []
    execute "ALTER IGNORE TABLE participations ADD UNIQUE KEY(user_id,site_id)"
    drop_table :sites_users
  end

  def self.down
    create_table(:sites_users, :id=>false,:options => 'type=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci') do |t|
      t.column :user_id, :integer
      t.column :site_id, :integer
      t.column :status, :integer
      t.column :contact_id, :integer
    end
    values = select_all("SELECT * FROM participations").map do |r|
      "(#{['user_id','site_id','status','contact_id'].map {|k| quote(r[k])}.join(', ')})"
    end
    execute "INSERT INTO sites_users (`user_id`,`site_id`,`status`,`contact_id`) VALUES #{values.join(', ')}" unless values == []
    drop_table :participations
  end
end
