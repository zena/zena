class RemoveIconField < ActiveRecord::Migration
  def self.up
    if Role.column_names.include?('icon')
      native_key = :prop
      prop_key   = 'prop'
      Role.all.each do |rec|
        next unless value = rec[native_key]
        prop  = rec.prop
        prop[prop_key] = value
        Zena::Db.execute "UPDATE #{rec.class.table_name} SET properties=#{Zena::Db.quote(rec.class.encode_properties(prop))} WHERE id=#{rec[:id]}"
      end
      remove_column :roles, :icon
    end
  end

  def self.down
  end
end
