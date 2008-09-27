class Contact < Reference
  zafu_readable      :fullname, :initials
  
  class << self
    
    def version_class
      ContactVersion
    end
    
    # Class list to which this class can change to
    def change_to_classes_for_form
      classes_for_form(:class => 'Contact')
    end
  end

  def filter_attributes(new_attributes)
    attributes = super
    if self[:name].blank? && attributes['name'].blank? && (attributes['c_name'] || attributes['c_first_name'])
      attributes.merge('name'    => (attributes['c_first_name'].to_s + ' ' + attributes['c_name'].to_s))
    else
      attributes
    end
  end
  
  def fullname
    version.content.fullname
  end
  
  def initials
    version.content.initials
  end
end
