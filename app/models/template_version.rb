=begin rdoc
This class stores version text for Template. See Version for details.

=== Content

Uses TemplateContent.
=end
class TemplateVersion < Version
  validates_presence_of       :content
  
  
  # TODO: test
  def self.content_class
    TemplateContent
  end
  
  # TODO: test
  def content
    return @content if @content
    @content = content_class.find_by_node_id(self[:node_id])
    
    unless @content
      # create new content
      @content = content_class.new
      @redaction_content = @content
      @content[:site_id] = node[:site_id]
    end  
    @content.node = node
    @content
  end
  
  # TODO: test
  def redaction_content
    content
  end
  
end