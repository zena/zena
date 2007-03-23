=begin rdoc
This class stores version text for Image. See Version for details.
=end
class ImageVersion < DocumentVersion
  before_create :set_image_text
  
  def content_class
    ImageContent
  end
  
  private
  def set_image_text
    if self[:text] == '' || !self[:text]
      self[:text] = "!#{self[:node_id]}!"
    end
  end
end
