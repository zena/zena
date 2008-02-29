class CreateAccessHits < ActiveRecord::Migration
  def self.up
    create_table :access_hits do |t|
      # %v %h %{%Y-%m-%d %H:%M:%S %z}t %T %>s %b %m \"%U\" \"%{Referer}i\" \"%{User-agent}i\" \"%r\"
      t.column :site_id          , :integer  # from %v
      t.column :node_id          , :integer
      
      t.column :remote_host      , :string, :limit => 50 # %h (ip)
      t.column :request_time     , :datetime             # %t
      t.column :request_duration , :integer              # %T
      t.column :status           , :integer              # %>s
      t.column :bytes_sent       , :integer              # %b
      t.column :request_method   , :string, :limit => 6  # %m
      t.column :request_uri      , :string, :limit => 255 # %U
      t.column :referer          , :string, :limit => 255 # \"%{Referer}i\"
      t.column :agent            , :string, :limit => 255 # \"%{User-agent}i\"
      t.column :request_line     , :string, :limit => 255 # \"%r\"  ??
      t.column :mode             , :string, :limit => 30
      t.column :format           , :string, :limit => 10
      t.column :lang             , :string, :limit => 6
    end
  end

  def self.down
    drop_table :access_hits
  end
end
