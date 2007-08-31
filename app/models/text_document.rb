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
      content_type =~ /^(text)/ && TYPE_TO_EXT[content_type.chomp] != ['rtf']
    end
    
    def version_class
      TextDocumentVersion
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
        $1
      end
    else
      nil
    end
  end
  
  def c_size
    version.text.size
  end
  
  def c_filename
    filename
  end
  
  private
    
    # Overwrite superclass (DocumentContent) behavior
    def valid_file
      return true
    end
  
    def document_before_validation
      super
      content = version.content
      content[:content_type] ||= 'text/plain'
      content[:ext]  ||= 'txt'
    end  
end
