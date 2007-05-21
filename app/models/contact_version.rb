=begin rdoc
This class stores version text for Contact. See Version for details.

=== Content

Uses ContactContent.
=end
class ContactVersion < Version
  before_validation :contact_version_before_validation
  
  def content_class
    ContactContent
  end
  
  private
    def contact_version_before_validation
      self.title = content.fullname
    end
end
