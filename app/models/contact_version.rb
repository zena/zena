=begin rdoc
This class stores version text for Contact. See Version for details.

=== Content

Uses ContactContent.
=end
class ContactVersion < Version
  before_validation_on_create :contact_version_before_validation_on_create
  
  def content_class
    ContactContent
  end
  
  private
    def contact_version_before_validation_on_create
      self.title = content.fullname if self[:title].blank?
    end
end
