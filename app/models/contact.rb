class Contact < Reference
  
  zafu_readable      :fullname, :initials
  
  # TODO: test
  def self.version_class
    ContactVersion
  end
  
  # FIXME: conflict with author !
  #def user
  #  secure(User) { User.find(:first, :conditions => ["contact_id = ?", self[:id]]) }
  #end
  
  def fullname
    version.content.fullname
  end
  
  def initials
    version.content.initials
  end
  
end
