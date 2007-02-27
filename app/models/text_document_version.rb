class TextDocumentVersion < DocumentVersion
  def content_class
    TextDocumentContent
  end
  private
  
  def get_content
    redaction_content unless content
  end
end
