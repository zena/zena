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
  # This is a callback from acts_as_multiversioned
  def version_class
    TextDocumentVersion
  end
end
