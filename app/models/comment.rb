=begin
Comments can be added on a per version basis. They are signed by the user commenting. Public comments
belong to the user _anon_ (see #User).

=end
class Comment < ActiveRecord::Base
  belongs_to :version
  belongs_to :author, :class_name=>"User", :foreign_key=>"user_id"
  
  # alias for created_at
  def date
    created_at
  end
end
