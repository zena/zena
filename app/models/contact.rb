class Contact < Page
  link :contact_for, :class_name=>'Project', :as=>'contact', :as_unique=>true
  link :favorites,   :class_name=>'Node'
  
  private
  # TODO: test
  def version_class
    ContactVersion
  end
end
