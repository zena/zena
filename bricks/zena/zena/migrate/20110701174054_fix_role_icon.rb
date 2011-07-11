class FixRoleIcon < ActiveRecord::Migration
  def self.up
    if Role.column_names.include?('icon')
      Role.all.each do |rec|
        next if rec.prop['icon']
        value = rec[:icon]
        if !value.blank?
          rec.prop['icon'] = value
          Zena::Db.execute "UPDATE #{rec.class.table_name} SET properties=#{Zena::Db.quote(rec.class.encode_properties(prop))} WHERE id=#{rec[:id]}"
          remove_column :roles, :icon
        end
      end
    end
  end

  def self.down
  end
end
