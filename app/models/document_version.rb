=begin rdoc
This class stores version text for Document. See Version for details.

=== Content

Uses DocumentContent.
=end
class DocumentVersion < Version
  validates_presence_of       :content
  def content_class
    DocumentContent
  end
end
