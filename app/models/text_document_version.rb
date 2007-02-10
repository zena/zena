class TextDocumentVersion < DocumentVersion
  def content_class
    TextDocumentContent
  end
  
  private
end
