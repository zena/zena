# This class stores version text for #Document. If a translation or new redaction of the text
# is created, both the new and the old #DocumentVersion refer to the same file (#DocumentContent)
class DocumentVersion < Version
  before_validation_on_create :get_content
  validates_presence_of       :content
  def content_class
    DocumentContent
  end
  
  private
  
  def get_content
    redaction_content unless content
  end
end
