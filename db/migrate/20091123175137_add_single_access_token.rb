class AddSingleAccessToken < ActiveRecord::Migration
  def self.up
    add_column :users, :single_access_token, :string
  end

  def self.down
    drop_column :users, :single_access_token
  end
end
