=begin rdoc
Any document that can be edited as text (html file, script, source code) is a text document. The file content is not stored in an external file. It is kept in the version text. This means that the content of such a document can be edited by editing the version's text.

=== Version

The version class used by text documents is the TextDocumentVersion.

=== Content

Content (file data) is stored in the TextDocumentVersion. The content class (TextDocumentContent) is responsible for faking the exitence of a real file.
=end
class TextDocument < Document
  class << self
    # Return true if a new text document can be created with the content_type. Used by the superclass Document to choose the corret subclass when creating a new object.
    def accept_content_type?(content_type)
      content_type =~ /^text/
    end
  end
  
  # Return the code language used for syntax highlighting.
  def content_lang
    ctype = version.content.content_type
    if ctype =~ /^text\/(.*)/
      case $1
      when 'x-ruby-script'
        'ruby'
      when 'html'
        'zafu'
      else
        nil
      end
    else
      nil
    end
  end
  
  private
  
  def prepare_before_validation
    super
    content = version.content
    content[:content_type] ||= 'text/plain'
    content[:ext]  ||= 'txt'
  end  
  # This is a callback from acts_as_multiversioned
  def version_class
    TextDocumentVersion
  end
end
