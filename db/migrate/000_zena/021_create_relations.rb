class CreateRelations < ActiveRecord::Migration
  def self.up
    create_table(:relations, :options => 'type=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci') do |t|
      t.column :source_role, :string,  :limit => 32
      t.column :source_kpath, :string, :limit => 16
      t.column :source_unique, :boolean
      t.column :source_icon, :string, :limit => 200
      
      t.column :target_role, :string,  :limit => 32
      t.column :target_kpath, :string, :limit => 16
      t.column :target_unique, :boolean
      t.column :target_icon, :string, :limit => 200
      
      t.column :site_id, :integer, :null => false
    end
    add_column :links, 'relation_id', :integer
    # load relations fixtures
    source_rel = {}
    target_rel = {}
    relations  = []
    YAML::load_documents( File.open( File.join(RAILS_ROOT, 'test', 'fixtures', 'relations.yml') ) ) do |entries|
      entries.each do |key,value|
        relation = []
        ['source_role', 'source_kpath', 'source_icon', 'target_role', 'target_kpath', 'target_icon'].each do |sym|
          relation << quote(value[sym])
        end
        relations << relation
      end
    end
    # create relations for each site
    Site.find(:all).each do |site|
      insert = relations.map do |rel|
        "(#{(rel + [site[:id]]).join(',')})"
      end
      puts insert.inspect
      execute "INSERT INTO relations (`source_role`,`source_kpath`,`source_icon`,`target_role`,`target_kpath`,`target_icon`,`site_id`) VALUES #{insert.join(', ')}"
      execute "UPDATE links,nodes SET relation_id = (SELECT id FROM relations WHERE source_role = links.role OR target_role = links.role AND site_id = #{site[:id]} LIMIT 1) WHERE links.source_id = nodes.id AND nodes.site_id = #{site[:id]}"
    end
  end

  def self.down
    drop_table :relations
    remove_column :links, 'relation_id'
  end
end
