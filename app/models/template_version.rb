=begin rdoc
This class stores version text for Template. See Version for details.

=== Content

Uses TemplateContent.
=end
class TemplateVersion < Version
  validates_presence_of       :content
  
  # Return the content for the version. Can it's 'own' content or the same as the version this one was copied from.
  def content
    return @content if @content
    @content = content_class.find_by_node_id(self[:node_id])
    
    unless @content
      # create new content
      @content = content_class.new
      @redaction_content = @content
      @content.node = node
      @content[:site_id] = node[:site_id]
    end
    @content
  end
  
  def content_class
    TemplateContent
  end
end