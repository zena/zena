# TODO: test all
class TextDocument < Document
  class << self
    def accept_content_type?(content_type)
      content_type =~ /^text/
    end
  end
  
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
