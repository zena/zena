class TransValue < ActiveRecord::Base
  belongs_to :trans_key, :foreign_key=>'key_id'
end
