class CorrectVclassKpath < ActiveRecord::Migration
  def self.up
    klasses = VirtualClass.find(:all)
    klasses.each do |vclass|
      Node.connection.execute "UPDATE nodes SET kpath = #{Node.connection.quote(vclass.kpath)} WHERE vclass_id = #{vclass[:id]}"
    end
  end

  def self.down
  end
end
