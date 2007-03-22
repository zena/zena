=begin rdoc
This class stores version text for Image. If a translation or new redaction of the text
is created, both the new and the old DocumentVersion refer to the same file (DocumentContent). See Document for more information.
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
