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
  
  
  # Parse text content and replace all reference to relative urls ('img/footer.png') by their zen_path ('/en/image34.png')
  def parse_assets!(helper)
    ctype = version.content.content_type
    case ctype
    when 'text/css'
      # use skin as root
      skin = section
      
      # not in a Skin. Cannot replace assets in CSS.
      # error
      unless skin.kind_of?(Skin)
        errors.add('base', 'Cannot parse assets if not in a Skin.')
        return
      end
      
      current_folder = skin.name
      
      # create/use redaction
      edit!
      
      version.text.gsub!(/url\(('|")(.*?)\1\)/) do
        if $2[0..6] == 'http://'
          $&
        else
          quote, src   = $1, $2
          if src =~ /\A\//
            # absolute path: do not touch
            "url(#{quote}#{src}#{quote})"
          else
            new_src = helper.send(:template_url_for_asset, :current_folder=>current_folder, :src => src, :parse_assets => true) || src
            "url(#{quote}#{new_src}#{quote})"
          end
        end
      end
    else
      # unknown type
      errors.add('base', "Invalid content-type #{ctype.inspect} to parse assets.")
    end
  end
  
  # Parse text and replace absolute urls ('/en/image30.jpg') by their relative value in the current skin ('img/bird.jpg')
  def unparse_assets!
    ctype = version.content.content_type
    case ctype
    when 'text/css'
      # use skin as root
      skin = section
      
      # not in a Skin. Cannot replace assets in CSS.
      # error
      unless skin.kind_of?(Skin)
        errors.add('base', 'Cannot parse assets if not in a Skin.')
        return
      end
      
      # create/use redaction
      edit!
      
      version.text.gsub!(/url\(('|")(.*?)\1\)/) do
        if $2[0..6] == 'http://'
          $&
        else
          quote, url   = $1, $2
          if url =~ /\A\/\w\w.*?(\d+)\./
            unless asset = secure(Node) { Node.find_by_zip($1) }
              errors.add('base', "could not find asset node #{url.inspect}")
              "url(#{quote}#{url}#{quote})"
            end
            if asset.fullpath =~ /\A#{skin.fullpath}\/(.+)/
              "url(#{quote}#{$1}.#{asset.c_ext}#{quote})"
            else
              errors.add('base', "could not find asset node #{url.inspect}")
              "url(#{quote}#{url}#{quote})"
            end
          else
            # bad format
            errors.add('base', "cannot unparse asset url #{url.inspect}")
            "url(#{quote}#{url}#{quote})"
          end
        end
      end
    else
      # unknown type
      errors.add('base', "invalid content-type #{ctype.inspect} to unparse assets.")
    end
  end
  
  # Return the code language used for syntax highlighting.
  def content_lang
    ctype = version.content.content_type
    if ctype =~ /^text\/(.*)/
      case $1
      when 'x-ruby-script'
        'ruby'
      when 'html', 'zafu'
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
