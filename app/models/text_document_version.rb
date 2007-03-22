=begin rdoc
This is the version used by TextDocument. It behave exactly like its superclass (DocumentVersion) except for the content class, set to TextDocumentContent.
=end
class TextDocumentVersion < DocumentVersion
  def content_class
    TextDocumentContent
  end
end
