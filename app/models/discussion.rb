class Discussion < ActiveRecord::Base
  has_many :comments, :conditions=>'reply_to IS NULL', :order=>'created_at ASC'
  has_many :all_comments, :class_name=>'Comment', :foreign_key=>'discussion_id', :order=>'created_at ASC'
end
