class CorrectVclassKpath < ActiveRecord::Migration
  def self.up
    unless $migrating_new_db
      klasses = VirtualClass.find(:all)
      klasses.each do |vclass|
        Node.connection.execute "UPDATE nodes SET kpath = #{Node.connection.quote(vclass.kpath)} WHERE vclass_id = #{vclass[:id]}"
      end
    end
  end

  def self.down
  end
end
