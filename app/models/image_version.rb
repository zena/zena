=begin rdoc
This class stores version text for Image. See Version for details.

=== Content

Uses ImageContent.
=end
class ImageVersion < DocumentVersion
  before_create :set_image_text
  
  def content_class
    ImageContent
  end
  
  private
  def set_image_text
    if self[:text].blank?
      self[:text] = "!#{self.node[:zip]}!"
    end
  end
end
