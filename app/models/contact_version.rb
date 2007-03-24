=begin rdoc
This class stores version text for Contact. See Version for details.

=== Content

Uses ContactContent.
=end
class ContactVersion < Version
  def content_class
    ContactContent
  end
end
