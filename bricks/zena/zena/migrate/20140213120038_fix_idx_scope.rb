class FixIdxScope < ActiveRecord::Migration
  FLDS  = %w{idx_class idx_scope idx_reverse_scope}
  TABLE = :roles
  def self.up
    FLDS.each do |fld|
      remove_column TABLE, fld rescue nil
    end
  end

  def self.down
    # noop
  end
end
