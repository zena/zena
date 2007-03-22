=begin rdoc
This class stores version text for Document. If a translation or new redaction of the text
is created, both the new and the old DocumentVersion refer to the same file (DocumentContent). See Document for more information.
=end
class DocumentVersion < Version
  validates_presence_of       :content
  def content_class
    DocumentContent
  end
end
