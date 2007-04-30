class Contact < Reference
  link :contact_for, :class_name=>'Project', :as=>'contact', :as_unique=>true
  link :favorites,   :class_name=>'Node'
  
  def user
    secure(User) { User.find(:first, :conditions => ["contact_id = ?", self[:id]]) }
  end
  
  private    
    # TODO: test
    def version_class
      ContactVersion
    end
end
