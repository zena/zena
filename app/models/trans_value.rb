class TransValue < ActiveRecord::Base
  belongs_to :trans_phrase, :foreign_key=>'phrase_id'
end
