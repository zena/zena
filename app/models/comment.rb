=begin
Comments can be added on a per discussion basis. They can be replies to other comments in the same
discussion. They are signed by the user commenting. Public comments
belong to the user _anon_ (see #User).
=end
class Comment < ActiveRecord::Base
  belongs_to :author, :class_name=>'User', :foreign_key=>'user_id'
  has_many   :replies, :class_name=>'Comment', :foreign_key=>'reply_to', :order=>'created_at ASC'
end
